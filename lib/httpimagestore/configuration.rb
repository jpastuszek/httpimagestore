require 'httpimagestore/thumbnail_class'

class Configuration
	def initialize(&block)
		@thumbnail_classes = {}
		instance_eval &block
	end

	def thumbnail_class(name, method, width, height, format = 'JPEG', options = {})
		@thumbnail_classes[name] = ThumbnailClass.new(name, method, width, height, format, options)
	end

	def get
		Struct.new(:thumbnail_classes).new(@thumbnail_classes)
	end
end

