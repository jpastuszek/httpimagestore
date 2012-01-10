require 'mime/types'

class Pathname
	def mime_extension(mime_type)
		mime = MIME::Types[mime_type].first or return extname
		'.' + (mime.extensions.select{|e| e.length == 3}.first or mime.extensions.first)
	end

	module AutoPath
		# <id>.<ext>
		def original_image(id, mime_type)
			"#{id.to_s}#{mime_extension(mime_type)}"
		end

		# <id>/<class>.<ext>
		def thumbnail_image(id, mime_type, thumbnail_class)
			"#{id.to_s}/#{thumbnail_class}#{mime_extension(mime_type)}"
		end
	end

	module CustomPath
		# abc/xyz.jpg => abc/<id>/xyz.jpg
		def original_image(id, mime_type)
			dirname + id.to_s + basename
		end

		# abc/xyz.jpg => abc/<id>/xyz-<class>.jpg
		def thumbnail_image(id, mime_type, thumbnail_class)
			dirname + id.to_s + "#{basename(extname)}-#{thumbnail_class}#{mime_extension(mime_type)}"
		end
	end
end

