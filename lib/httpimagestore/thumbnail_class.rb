class ThumbnailClass
	def initialize(name, method, width, height, format = 'JPEG', options = {})
		@name = name
		@method = method
		@width = width
		@height = height 
		@format = format
		@options = options
	end

	attr_reader :name, :method, :width, :height, :format, :options
end

