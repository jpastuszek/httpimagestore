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
			configuration.s3 = Struct.new(:key, :secret, :ssl, :client).new
			configuration.s3.key = node.attribute('key') or raise NoAttributeError.new(node, 'key')
			configuration.s3.secret = node.attribute('secret') or raise NoAttributeError.new(node, 'secret')
			configuration.s3.ssl = 
				case node.attribute('ssl')
				when nil
					true
				when true
					true
				when false
					false
				else
					raise BadValueError.new(node, 'ssl', 'true or false')
				end

			log.info "S3 client using '#{configuration.s3.key}' key and #{configuration.s3.ssl ? 'HTTPS' : 'HTTP'} connections"
			configuration.s3.client = AWS::S3.new(
				access_key_id: configuration.s3.key,
				secret_access_key: configuration.s3.secret,
				#logger: logger_for(AWS::S3),
				use_ssl: configuration.s3.ssl
			)
		end
	end
	Global.register_node_parser S3

	class S3Source
		include ClassLogging

		def self.match(node)
			node.name == 'source_s3'
		end

		def self.parse(configuration, node)
			image_name = node.values.first or raise NoValueError.new(node, 'image name')
			bucket = node.attribute('bucket') or raise NoAttributeError.new(node, 'bucket')
			path_spec = node.attribute('path') or raise NoAttributeError.new(node, 'path')
			
			configuration.image_sources << self.new(image_name, configuration, bucket, path_spec)
		end

		def initialize(image_name, configuration, bucket, path_spec)
			@image_name = image_name
			@configuration = configuration
			@bucket = bucket
			@path_spec = path_spec
		end

		def realize(request_state)
			@configuration.global.s3 or raise S3NotConfiguredError
			client = @configuration.global.s3.client or fail 'no S3 client'

			path = @configuration.global.paths[@path_spec]
			path = path.render(request_state.locals)

			log.info "sourcing '#{@image_name}' image from S3 '#{@bucket}' bucket: #{path}"

			begin
				bucket = client.buckets[@bucket]
				object = bucket.objects[path]
				image = Image.new(object.read, object.head[:content_type])

				image.source_path = path
#				image.source_url = "#{@configuration.global.s3.ssl ? 'https' : 'http'}://#{@bucket}.s3.amazonaws.com/#{path}"
				image.source_url = object.url_for(:read, expires: 30749220000).to_s # expire in 999 years

				request_state.images[@image_name] = image
			rescue AWS::S3::Errors::AccessDenied
				raise S3AccessDenied.new(@bucket, path)
			rescue AWS::S3::Errors::NoSuchBucket
				raise S3NoSuchBucketError.new(@bucket)
			rescue AWS::S3::Errors::NoSuchKey
				 raise S3NoSuchKeyError.new(@bucket, path)
			end
		end
	end
	Handler::register_node_parser S3Source
end

