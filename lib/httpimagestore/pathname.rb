require 'mime/types'

class Pathname
	def original_image(id)
		dirname + id.to_s + basename
	end

	def thumbnail_image(id, thumbnail_class, mime_type)
		dirname + id.to_s + "#{basename(extname)}-#{thumbnail_class}#{mime_extension(mime_type) or extname}"
	end

	private

	def mime_extension(mime_type)
		mime = MIME::Types[mime_type].first or return nil
		'.' + (mime.extensions.select{|e| e.length == 3}.first or mime.extensions.first)
	end
end

