require 'digest/sha2'
require 'mime/types'
require 'pathname'

module Plugin
	module ImagePath
		class CouldNotDetermineFileExtensionError < ArgumentError
			def initialize(mime_type)
				super "could not determine file extension for mime type: #{mime_type}"
			end
		end

		class ImagePathBase
			def initialize(id)
				@id = id.to_s
			end

			def mime_extension(mime_type)
				mime = MIME::Types[mime_type].first or raise CouldNotDetermineFileExtensionError, mime_type
				'.' + (mime.extensions.select{|e| e.length == 3}.first or mime.extensions.first)
			end
		end

		class Auto < ImagePathBase
			def original_image(mime_type)
				"#{@id}#{mime_extension(mime_type)}"
			end

			def thumbnail_image(mime_type, thumbnail_class)
				"#{@id}/#{thumbnail_class}#{mime_extension(mime_type)}"
			end
		end

		class Custom < ImagePathBase
			def initialize(id, path)
				super id
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

		def digest(data)
			Digest::SHA2.new.update(data).to_s[0,16]
		end

		def custom_path(id, path)
			Custom.new(id, path)
		end

		def auto_path(id)
			Auto.new(id)
		end
	end
end

