class Pathname
	def original_image(id)
		dirname + id.to_s + basename
	end

	def thumbnail_image(id, thumbnail_class)
		dirname + id.to_s + "#{basename(extname)}-#{thumbnail_class}#{extname}"
	end
end

