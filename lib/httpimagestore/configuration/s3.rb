require 'aws-sdk'
require 'digest/sha2'
require 'msgpack'
require 'httpimagestore/aws_sdk_regions_hack'
require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler'

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

			def initialize(root_dir, write_mode = false)
				@root = Pathname.new(root_dir)
				@root.directory? or raise CacheRootNotDirError.new(root_dir)
				@write_mode = write_mode
				if @write_mode
					@root.writable? or raise CacheRootNotWritableError.new(root_dir)
				end
				@root.executable? or raise CacheRootNotAccessibleError.new(root_dir)
			end

			def cache_file(bucket, key)
				File.join(Digest::SHA2.new.update("#{bucket}/#{key}").to_s[0,32].match(/(..)(..)(.*)/).captures)
			end

			def try_open(bucket, key)
				file = @root + cache_file(bucket, key)

				if @write_mode
					file.dirname.directory? or file.dirname.mkpath
				else
					return false unless file.readable?
				end

				file.open(@write_mode ? 'w' : 'r') do |io|
					yield io
				end
				return true
			end
		end

		class CachedObject
			def initialize(io)
				@io = io
				head_length = @io.read(4).unpack('L').first
				@header = MessagePack.unpack(@io.read(head_length))
				@header['headers'].default_proc = proc do |hash, key|
					# MessagePack does not support symbols
					hash[key.to_s]
				end
			end

			def read(options = {})
				if range = options[:range]
					@io.seek(range.first, IO::SEEK_CUR)
					@io.read(range.last - range.first)
				else
					@io.read
				end
			end

			def write(data, options = {})
				@io.write(data)
			end

			def url_for(*args)
				@header['url_for']
			end

			def public_url(*args)
				@header['public_url']
			end

			def head
				@header['headers']
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

			bucket, path_spec, public_access, cache_control, prefix, cache_root, if_image_name_on = 
				*node.grab_attributes('bucket', 'path', 'public', 'cache-control', 'prefix', 'cache-root', 'if-image-name-on')
			public_access = false if public_access.nil?
			prefix = '' if prefix.nil?

			self.new(
				configuration.global, 
				image_name, 
				InclusionMatcher.new(image_name, if_image_name_on),
				bucket, 
				path_spec, 
				public_access, 
				cache_control,
				prefix,
				cache_root
			)
		end

		def initialize(global, image_name, matcher, bucket, path_spec, public_access, cache_control, prefix, cache_root)
			super global, image_name, matcher
			@bucket = bucket
			@path_spec = path_spec
			@public_access = public_access
			@cache_control = cache_control
			@prefix = prefix

			@cache_root = nil
			begin
				if cache_root
					@cache_root = CacheRoot.new(cache_root)
					log.info "using S3 object cache directory: #{cache_root}"
				else
					log.info "S3 object cache not configured (no cache-root)"
				end
			rescue CacheRoot::CacheRootNotDirError => error
				log.warn "not using S3 object cache: #{error}"
			end

			local :bucket, @bucket
		end

		def client
			@global.s3 or raise S3NotConfiguredError
		end

		def url(object)
			if @public_access
				object.public_url.to_s
			else
				object.url_for(:read, expires: 60 * 60 * 24 * 365 * 20).to_s # expire in 20 years
			end
		end

		def object(path)
			begin
				key = @prefix + path
				begin
					@cache_root.try_open(@bucket, key) do |io|
						log.debug{"S3 object cache hit '#{@bucket}/#{key}' [#{@cache_root.cache_file(@bucket, key)}]"}
						return yield CachedObject.new(io)
					end
					log.debug{"S3 object cache miss '#{@bucket}/#{key}' [#{@cache_root.cache_file(@bucket, key)}]"}
				rescue IOError => error
					log.warn "cannot use cached S3 object '#{@cache_root.cache_file(@bucket, key)}': #{error}"
				end if @cache_root
				return yield client.buckets[@bucket].objects[key]
			rescue AWS::S3::Errors::AccessDenied
				raise S3AccessDenied.new(@bucket, path)
			rescue AWS::S3::Errors::NoSuchBucket
				raise S3NoSuchBucketError.new(@bucket)
			rescue AWS::S3::Errors::NoSuchKey
				 raise S3NoSuchKeyError.new(@bucket, path)
			end
		end
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
						object.read range: 0..(limit + 1)
					end
					S3SourceStoreBase.stats.incr_total_s3_source
					S3SourceStoreBase.stats.incr_total_s3_source_bytes(data.bytesize)

					image = Image.new(data, object.head[:content_type])
					image.source_url = url(object)
					image
				end
			end
		end
	end
	Handler::register_node_parser S3Source

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
					options[:content_type] = image.mime_type
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
end


