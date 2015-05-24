require 'aws-sdk'
require 'digest/sha2'
require 'msgpack'
require 'addressable/uri'
require 'httpimagestore/aws_sdk_regions_hack'
require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler/source_store_base'
require 'httpimagestore/configuration/source_failover'

module Configuration
	class S3NotConfiguredError < ConfigurationError
		def initialize
			super "S3 client not configured"
		end
	end

	class S3NoSuchBucketError < ConfigurationError
		def initialize(bucket)
			super "S3 bucket '#{bucket}' does not exist"
		end
	end

	class S3NoSuchKeyError < ConfigurationError
		def initialize(bucket, path)
			super "S3 bucket '#{bucket}' does not contain key '#{path}'"
		end
	end

	class S3AccessDenied < ConfigurationError
		def initialize(bucket, path)
			super "access to S3 bucket '#{bucket}' or key '#{path}' was denied"
		end
	end

	class S3
		include ClassLogging

		def self.match(node)
			node.name == 's3'
		end

		def self.parse(configuration, node)
			configuration.s3 and raise StatementCollisionError.new(node, 's3')

			node.grab_values
			node.required_attributes('key', 'secret')
			node.valid_attribute_values('ssl', true, false, nil)

			key, secret, ssl = node.grab_attributes('key', 'secret', 'ssl')
			ssl = true if ssl.nil?

			configuration.s3 = AWS::S3.new(
				access_key_id: key,
				secret_access_key: secret,
				logger: logger_for(AWS::S3),
				log_level: :debug,
				use_ssl: ssl
			)

			log.info "S3 client using '#{key}' key and #{ssl ? 'HTTPS' : 'HTTP'} connections"
		end
	end
	Global.register_node_parser S3

	class S3SourceStoreBase < SourceStoreBase
		include ClassLogging

		class CacheRoot
			CacheRootError = Class.new ArgumentError
			class CacheRootNotDirError < CacheRootError
				def initialize(root_dir)
					super "S3 object cache directory '#{root_dir}' does not exist or not a directory"
				end
			end

			class CacheRootNotWritableError < CacheRootError
				def initialize(root_dir)
					super "S3 object cache directory '#{root_dir}' is not writable"
				end
			end

			class CacheRootNotAccessibleError < CacheRootError
				def initialize(root_dir)
					super "S3 object cache directory '#{root_dir}' is not readable"
				end
			end

			class CacheFile < Pathname
				def initialize(path)
					super
					@header = nil
				end

				def header
					begin
						read(0)
					rescue
						@header = {}
					end unless @header
					@header or fail 'no header data'
				end

				def read(max_bytes = nil)
					open('rb') do |io|
						io.flock(File::LOCK_SH)
						@header = read_header(io)
						return io.read(max_bytes)
					end
				end

				def write(data)
					dirname.directory? or dirname.mkpath
					open('ab') do |io|
						# opened but not truncated before lock can be obtained
						io.flock(File::LOCK_EX)

						# now get rid of the old content if any
						io.seek 0, IO::SEEK_SET
						io.truncate 0

						begin
							header = MessagePack.pack(@header)
							io.write [header.length].pack('L') # header length
							io.write header
							io.write data
						rescue
							unlink # remove broken cache file
							raise
						end
					end
				end

				private

				def read_header_length(io)
					head_length = io.read(4)
					fail 'no header length' unless head_length and head_length.length == 4
					head_length.unpack('L').first
				end

				def read_header(io)
					MessagePack.unpack(io.read(read_header_length(io)))
				end
			end

			def initialize(root_dir)
				@root = Pathname.new(root_dir)
				@root.directory? or raise CacheRootNotDirError.new(root_dir)
				@root.executable? or raise CacheRootNotAccessibleError.new(root_dir)
				@root.writable? or raise CacheRootNotWritableError.new(root_dir)
			end

			def cache_file(bucket, key)
				CacheFile.new(File.join(@root.to_s, *Digest::SHA2.new.update("#{bucket}/#{key}").to_s[0,32].match(/(..)(..)(.*)/).captures))
			end
		end

		class S3Object
			def initialize(client, bucket, key)
				@client = client
				@bucket = bucket
				@key = key
			end

			def s3_object
				return @s3_object if @s3_object
				@s3_object = @client.buckets[@bucket].objects[@key]
			end

			def read(max_bytes = nil)
				options = {}
				options[:range] = 0..max_bytes if max_bytes
				s3_object.read(options)
			end

			def write(data, options = {})
				s3_object.write(data, options)
			end

			def private_url
				s3_object.url_for(:read, expires: 60 * 60 * 24 * 365 * 20)
			end

			def public_url
				s3_object.public_url
			end

			def content_type
				s3_object.head[:content_type]
			end
		end

		class CacheObject < S3Object
			extend Stats
			def_stats(
				:total_s3_cache_hits,
				:total_s3_cache_misses,
				:total_s3_cache_errors,
			)

			include ClassLogging

			def initialize(cache_file, client, bucket, key)
				super(client, bucket, key)

				@cache_file = cache_file
				@dirty = false

				yield self

				# save object if new data was read/written to/from S3 and no error happened
				write_cache if dirty?
			end

			def read(max_bytes = nil)
				begin
					@data = @cache_file.read(max_bytes)
					CacheObject.stats.incr_total_s3_cache_hits
					log.debug{"S3 object cache hit for bucket: '#{@bucket}' key: '#{@key}' [#{@cache_file}]: header: #{@cache_file.header}"}
					return @data
				rescue Errno::ENOENT
					CacheObject.stats.incr_total_s3_cache_misses
					log.debug{"S3 object cache miss for bucket: '#{@bucket}' key: '#{@key}' [#{@cache_file}]"}
				rescue => error
					CacheObject.stats.incr_total_s3_cache_errors
					log.warn "cannot use cached S3 object for bucket: '#{@bucket}' key: '#{@key}' [#{@cache_file}]", error
				end
				@data = super
				dirty! :read
				return @data
			end

			def write(data, options = {})
				super
				@data = data
				@cache_file.header['content_type'] = options[:content_type] if options[:content_type]
				dirty! :write
			end

			def private_url
				url = @cache_file.header['private_url'] and return Addressable::URI.parse(url)
				dirty! :private_url
				url = super
				@cache_file.header['private_url'] = url.to_s
				Addressable::URI.parse(url)
			end

			def public_url
				url = @cache_file.header['public_url'] and return Addressable::URI.parse(url)
				dirty! :public_url
				url = super
				@cache_file.header['public_url'] = url.to_s
				Addressable::URI.parse(url)
			end

			def content_type
				@cache_file.header['content_type'] ||= (dirty! :content_type; super)
			end

			private

			def write_cache
				begin
					log.debug{"S3 object is dirty, wirting cache file for bucket: '#{@bucket}' key: '#{@key}' [#{@cache_file}]; header: #{@cache_file.header}"}

					raise 'nil data!' unless @data
					@cache_file.write(@data)
				rescue => error
					log.warn "cannot store S3 object in cache for bucket: '#{@bucket}' key: '#{@key}' [#{@cache_file}]", error
				ensure
					@dirty = false
				end
			end

			def dirty!(reason = :unknown)
				log.debug{"marking cache dirty for reason: #{reason}"}
				@dirty = true
			end

			def dirty?
				@dirty
			end
		end

		extend Stats
		def_stats(
			:total_s3_store,
			:total_s3_store_bytes,
			:total_s3_source,
			:total_s3_source_bytes
		)

		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first

			node.required_attributes('bucket', 'path')
			node.valid_attribute_values('public_access', true, false, nil)

			bucket, path_spec, public_access, cache_control, prefix, cache_root, remaining =
				*node.grab_attributes_with_remaining('bucket', 'path', 'public', 'cache-control', 'prefix', 'cache-root')
			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(remaining)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			public_access = false if public_access.nil?
			prefix = '' if prefix.nil?

			s3 = self.new(
				configuration.global,
				image_name,
				bucket,
				path_spec,
				public_access,
				cache_control,
				prefix,
				cache_root
			)
			s3.with_conditions(conditions)
			s3
		end

		def initialize(global, image_name, bucket, path_spec, public_access, cache_control, prefix, cache_root)
			super(global, image_name, path_spec)

			@bucket = bucket
			@public_access = public_access
			@cache_control = cache_control
			@prefix = prefix

			@cache_root = nil
			begin
				if cache_root
					@cache_root = CacheRoot.new(cache_root)
					log.info "using S3 object cache directory '#{cache_root}' for image '#{image_name}'"
				else
					log.info "S3 object cache not configured (no cache-root) for image '#{image_name}'"
				end
			rescue CacheRoot::CacheRootNotDirError => error
				log.warn "not using S3 object cache for image '#{image_name}'", error
			end

			config_local :bucket, @bucket
		end

		def client
			@global.s3 or raise S3NotConfiguredError
		end

		def url(object)
			if @public_access
				object.public_url
			else
				object.private_url
			end
		end

		def object(path)
			begin
				key = @prefix + path
				image = nil

				if @cache_root
					begin
						cache_file = @cache_root.cache_file(@bucket, key)
						CacheObject.new(cache_file, client, @bucket, key) do |obj|
							image = yield obj
						end
						return image
					rescue Errno::EACCES, IOError => error
						log.warn "cannot use S3 object cache for bucket: '#{@bucket}' key: '#{key}' [#{cache_file}]", error
					end
				end
				return yield S3Object.new(client, @bucket, key)
			rescue AWS::S3::Errors::AccessDenied
				raise S3AccessDenied.new(@bucket, path)
			rescue AWS::S3::Errors::NoSuchBucket
				raise S3NoSuchBucketError.new(@bucket)
			rescue AWS::S3::Errors::NoSuchKey
				 raise S3NoSuchKeyError.new(@bucket, path)
			end
		end

		S3SourceStoreBase.logger = Handler.logger_for(S3SourceStoreBase)
		CacheObject.logger = S3SourceStoreBase.logger_for(CacheObject)
	end

	class S3Source < S3SourceStoreBase
		def self.match(node)
			node.name == 'source_s3'
		end

		def self.parse(configuration, node)
			configuration.sources << super
		end

		def realize(request_state)
			put_sourced_named_image(request_state) do |image_name, rendered_path|
				log.info "sourcing '#{image_name}' image from S3 '#{@bucket}' bucket under '#{rendered_path}' key"

				object(rendered_path) do |object|
					data = request_state.memory_limit.get do |limit|
						object.read(limit + 1)
					end
					S3SourceStoreBase.stats.incr_total_s3_source
					S3SourceStoreBase.stats.incr_total_s3_source_bytes(data.bytesize)

					image = Image.new(data, object.content_type)
					image.source_url = url(object)
					image
				end
			end
		end

		def to_s
			"S3Source[image_name: '#{image_name}' bucket: '#{@bucket}' prefix: '#{@prefix}' path_spec: '#{path_spec}']"
		end
	end
	Handler::register_node_parser S3Source
	SourceFailover::register_node_parser S3Source

	class S3Store < S3SourceStoreBase
		def self.match(node)
			node.name == 'store_s3'
		end

		def self.parse(configuration, node)
			configuration.stores << super
		end

		def realize(request_state)
			get_named_image_for_storage(request_state) do |image_name, image, rendered_path|
				acl = @public_access ?  :public_read : :private

				log.info "storing '#{image_name}' image in S3 '#{@bucket}' bucket under '#{rendered_path}' key with #{acl} access"

				object(rendered_path) do |object|
					image.mime_type or log.warn "storing '#{image_name}' in S3 '#{@bucket}' bucket under '#{rendered_path}' key with unknown mime type"

					options = {}
					options[:single_request] = true
					options[:content_type] = image.mime_type if image.mime_type
					options[:acl] = acl
					options[:cache_control] = @cache_control if @cache_control

					object.write(image.data, options)
					S3SourceStoreBase.stats.incr_total_s3_store
					S3SourceStoreBase.stats.incr_total_s3_store_bytes(image.data.bytesize)

					image.store_url = url(object)
				end
			end
		end
	end
	Handler::register_node_parser S3Store
	StatsReporter << S3SourceStoreBase.stats
	StatsReporter << S3SourceStoreBase::CacheObject.stats
end

