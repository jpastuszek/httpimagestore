require 'mime/types'
require 'pathname'

class ImagePath
	class CouldNotDetermineFileExtensionError < ArgumentError
		def initialize(mime_type)
			super "could not determine file extension for mime type: #{mime_type}"
		end
	end

	def initialize(id)
		@id = id.to_s
	end

	private

	def mime_extension(mime_type)
		mime = MIME::Types[mime_type].first or raise CouldNotDetermineFileExtensionError, mime_type
		'.' + (mime.extensions.select{|e| e.length == 3}.first or mime.extensions.first)
	end

	class Auto < ImagePath
		def original_image(mime_type)
			"#{@id}#{mime_extension(mime_type)}"
		end

		def thumbnail_image(mime_type, thumbnail_class)
			"#{@id}/#{thumbnail_class}#{mime_extension(mime_type)}"
		end
	end

	class Custom < ImagePath
		def initialize(id, path)
			super(id)
			@path = Pathname.new(path)
		end

		def original_image(mime_type)
			extension = begin
				mime_extension(mime_type)
			rescue CouldNotDetermineFileExtensionError
				raise if @path.extname.empty?
				@path.extname
			end

			(@path.dirname + @id + "#{@path.basename(@path.extname)}#{extension}").to_s
		end

		def thumbnail_image(mime_type, thumbnail_class)
			(@path.dirname + @id + "#{@path.basename(@path.extname)}-#{thumbnail_class}#{mime_extension(mime_type)}").to_s
		end
	end
end

