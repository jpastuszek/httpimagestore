require 'aws-sdk'
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

	class S3Base
		include ClassLogging
		include Exclusion

		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first

			node.required_attributes('bucket', 'path')
			node.valid_attribute_values('public_access', true, false, nil)

			bucket, path_spec, cache_control, public_access, if_image_name_on = 
				*node.grab_attributes('bucket', 'path', 'cache-control', 'public', 'if-image-name-on')
			public_access = false if public_access.nil?

			self.new(
				configuration.global, 
				image_name, 
				bucket, 
				path_spec, 
				public_access, 
				cache_control, 
				OptionalExclusionMatcher.new(image_name, if_image_name_on)
			)
		end

		def initialize(global, image_name, bucket, path_spec, public_access, cache_control, exclusion_matcher = nil)
			@global = global
			@image_name = image_name
			@bucket = bucket
			@path_spec = path_spec
			@public_access = public_access
			@cache_control = cache_control
			@exclusion_matcher = exclusion_matcher
		end

		def client
			@global.s3 or raise S3NotConfiguredError
		end

		def rendered_path(request_state)
			path = @global.paths[@path_spec]
			path.render(request_state.locals)
		end

		def url(object)
			if @public_access
				object.public_url.to_s
			else
				object.url_for(:read, expires: 30749220000).to_s # expire in 999 years
			end
		end

		def object(path)
			begin
				bucket = client.buckets[@bucket]
				yield bucket.objects[path]
			rescue AWS::S3::Errors::AccessDenied
				raise S3AccessDenied.new(@bucket, path)
			rescue AWS::S3::Errors::NoSuchBucket
				raise S3NoSuchBucketError.new(@bucket)
			rescue AWS::S3::Errors::NoSuchKey
				 raise S3NoSuchKeyError.new(@bucket, path)
			end
		end
	end

	class S3Source < S3Base
		def self.match(node)
			node.name == 'source_s3'
		end

		def self.parse(configuration, node)
			configuration.image_sources << super
		end

		def realize(request_state)
			rendered_path = rendered_path(request_state)
			log.info "sourcing '#{@image_name}' image from S3 '#{@bucket}' bucket under '#{rendered_path}' key"

			object(rendered_path) do |object|
				image = Image.new(object.read, object.head[:content_type])

				image.source_path = rendered_path
				image.source_url = url(object)

				request_state.images[@image_name] = image
			end
		end
	end
	Handler::register_node_parser S3Source

	class S3Store < S3Base
		def self.match(node)
			node.name == 'store_s3'
		end

		def self.parse(configuration, node)
			configuration.stores << super
		end

		def realize(request_state)
			rendered_path = rendered_path(request_state)
			acl = @public_access ?  :public_read : :private

			log.info "storing '#{@image_name}' image in S3 '#{@bucket}' bucket under '#{rendered_path}' key with #{acl} access"

			object(rendered_path) do |object|
				image = request_state.images[@image_name]
				image.mime_type or log.warn "storing '#{@image_name}' in S3 '#{@bucket}' bucket under '#{rendered_path}' key with unknown mime type"

				options = {}
				options[:single_request] = true
				options[:content_type] = image.mime_type
				options[:acl] = acl
				options[:cache_control] = @cache_control if @cache_control

				object.write(image.data, options)

				image.store_path = rendered_path
				image.store_url = url(object)
			end
		end
	end
	Handler::register_node_parser S3Store
end

