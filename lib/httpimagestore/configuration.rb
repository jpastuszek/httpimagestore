require 'httpimagestore/thumbnail_class'
require 'pathname'

class Configuration
	def initialize(&block)
		@thumbnail_classes = {}
		@thumbnailer_url = "http://localhost:3100"

		instance_eval &block
	end

	def self.from_file(file)
		file = Pathname.pwd + file
		Configuration.new do
			 eval(file.read, nil, file.to_s)
		end
	end

	def thumbnail_class(name, method, width, height, format = 'JPEG', options = {})
		@thumbnail_classes[name] = ThumbnailClass.new(name, method, width, height, format, options)
	end

	def s3_key(id, secret)
		@s3_key_id = id
		@s3_key_secret = secret
	end

	def s3_bucket(bucket)
		@s3_bucket = bucket
	end

	def thumbnailer_url(url)
		@thumbnailer_url = url
	end

	def get
		Struct.new(:thumbnail_classes, :s3_key_id, :s3_key_secret, :s3_bucket, :thumbnailer_url).new(@thumbnail_classes, @s3_key_id, @s3_key_secret, @s3_bucket, @thumbnailer_url)
	end
end

