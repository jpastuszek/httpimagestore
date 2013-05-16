require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler'
require 'pathname'

module Configuration
	class FileStorageOutsideOfRootDirError < ConfigurationError
		def initialize(image_name, file_path)
			super "error while processing image '#{image_name}': file storage path '#{file_path.to_s}' outside of root direcotry"
		end
	end

	class FileBase
		def self.parse(configuration, node)
			image_name = node.values.first or raise NoValueError.new(node, 'image name')
			root_dir = node.attribute('root') or raise NoAttributeError.new(node, 'root')
			path_spec = node.attribute('path') or raise NoAttributeError.new(node, 'path')

			self.new(image_name, configuration, root_dir, path_spec)
		end

		def initialize(image_name, configuration, root_dir, path_spec)
			@image_name = image_name
			@configuration = configuration
			@root_dir = Pathname.new(root_dir).cleanpath
			@path_spec = path_spec
		end

		private

		def final_path(request_state)
			path = @configuration.global.paths[@path_spec]
			rendered_path = Pathname.new(path.render(request_state.locals))

			final_path = (@root_dir + rendered_path).cleanpath
			final_path.to_s =~ /^#{@root_dir.to_s}/ or raise FileStorageOutsideOfRootDirError.new(@image_name, rendered_path)

			final_path
		end
	end

	class FileSource < FileBase
		include ClassLogging

		def self.match(node)
			node.name == 'source_file'
		end

		def self.parse(configuration, node)
			configuration.image_sources << super
		end

		def realize(request_state)
			path = final_path(request_state)

			log.info "sourcing '#{@image_name}' from file '#{path}'"
			image = Image.new(path.open('r'){|io| io.read})

			image.source_path = path.to_s
			image.source_url = "file://#{path.to_s}"

			request_state.images[@image_name] = image
		end
	end
	Handler::register_node_parser FileSource
	
	class FileStore < FileBase
		include ClassLogging

		def self.match(node)
			node.name == 'store_file'
		end

		def self.parse(configuration, node)
			configuration.stores << super
		end

		def realize(request_state)
			image = request_state.images[@image_name]
			path = final_path(request_state)

			image.store_path = path.to_s
			image.store_url = "file://#{path.to_s}"

			log.info "storing '#{@image_name}' in file '#{path}' (#{image.data.length} bytes)"
			path.open('w'){|io| io.write image.data}
		end
	end
	Handler::register_node_parser FileStore
end

