require 'httpimagestore/thumbnail_class'
require 'pathname'

class Configuration
	class ThumbnailClassDoesNotExistError < RuntimeError
		def initialize(name)
			super "Class '#{name}' does not exist"
		end
	end

	def initialize(&block)
		@thumbnail_classes = Hash.new do |h, k|
			raise ThumbnailClassDoesNotExistError, k
		end

		@thumbnailer_url = "http://localhost:3100"

		@port = 3000
		@bind = 'localhost'

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

	def port(no)
		@port = no
	end

	def bind(address)
		@bind = address
	end

	def get
		Struct.new(:thumbnail_classes, :s3_key_id, :s3_key_secret, :s3_bucket, :thumbnailer_url, :port, :bind).new(@thumbnail_classes, @s3_key_id, @s3_key_secret, @s3_bucket, @thumbnailer_url, @port, @bind)
	end

	def put(sinatra)
		get.each_pair do |key, value|
			sinatra.set key, value
		end
	end
end

