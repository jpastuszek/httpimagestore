require 'right_aws'

module Plugin
	module S3
		class Service
			include ClassLogging

			def initialize(key_id, key_secret, bucket, options = {})
				@options = {
					cache_control: [],
					upload_retry_time: 2,
					upload_retry_initial_delay: 0.1
				}.merge(options)

				RightAws::AWSErrorHandler::reiteration_time = @options[:upload_retry_time]
				RightAws::AWSErrorHandler::reiteration_start_delay = @options[:upload_retry_initial_delay]

				@s3 = RightAws::S3.new(key_id, key_secret, logger: log.logger_for(RightAws::S3))

				log.info "initializing S3 with bucket: #{bucket}"
				@bucket = @s3.bucket(bucket) or fail "no buckte '#{bucket}' found"
			end

			def put_image(image_path, content_type, data)
				log.debug "putting image in bucket '#{@bucket.name}': #{image_path}"

				headers = {}
				headers['Content-Type'] = content_type
				headers['Cache-Control'] = @options[:cache_control].join(', ') unless @options[:cache_control].empty?

				@bucket.put(image_path, data, {}, 'public-read', headers)

				"http://#{@bucket.name}.s3.amazonaws.com/#{image_path}"
			end
		end

		def self.setup(app)
			Service.logger = app.logger_for(Service)
			@@service = Service.new(
				app.settings[:s3_key_id], 
				app.settings[:s3_key_secret], 
				app.settings[:s3_bucket], 
				cache_control: app.settings[:cache_control],
				upload_retry_time: app.settings[:upload_retry_time],
				upload_retry_initial_delay: app.settings[:upload_retry_initial_delay]
			)
		end

		def s3
			@@service
		end
	end
end

