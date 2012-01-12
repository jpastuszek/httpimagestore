require 's3'
require 'retry-this'

class S3Service
	def initialize(key_id, key_secret, bucket, options = {})
		@options = options
		@logger = (options[:logger] or Logger.new('/dev/null'))

		@s3 = S3::Service.new(:access_key_id => key_id, :secret_access_key => key_secret)

		@logger.info "Getting bucket: #{bucket}"
		@bucket = @s3.buckets.find(bucket) or fail "no buckte '#{bucket}' found"
	end

	def put_image(image_path, content_type, data)
		@logger.info "Putting image in bucket '#{@bucket.name}': #{image_path}"

		file = @bucket.objects.build(image_path)
		file.content_type = content_type
		file.content = data

		RetryThis.retry_this(:times => 3, :sleep => 0.1, :error_types => [Errno::ECONNRESET, S3::Error::RequestTimeout]) do |attempt|
			@logger.warn "Retrying S3 save operation" if attempt > 1
			file.save
		end

		"http://#{@bucket.name}.s3.amazonaws.com/#{image_path}"
	end
end

