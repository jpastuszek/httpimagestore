require 'pathname'

module Configuration
	StorageOutsideOfRootDirError = Class.new ConfigurationError

	class FileBase
		def self.parse(configuration, node)
			image_name = node.values.first or raise MissingArgumentError, 'image name'
			root_dir = node.attribute('root') or raise MissingArgumentError, 'root'
			path_spec = node.attribute('path') or raise MissingArgumentError, 'path'

			self.new(image_name, configuration, root_dir, path_spec)
		end

		def initialize(image_name, configuration, root_dir, path_spec)
			@image_name = image_name
			@configuration = configuration
			@root_dir = Pathname.new(root_dir).realpath
			@path_spec = path_spec
		end

		private

		def final_path(request_state)
			path = @configuration.global.paths[@path_spec] or raise MissingStatementError, "no '#{@path_spec}' path specification found"
			rendered_path = path.render(request_state.locals)

			final_path = (@root_dir + rendered_path).cleanpath
			final_path.to_s =~ /^#{@root_dir.to_s}/ or raise StorageOutsideOfRootDirError, "file storage path outside of root direcotry: #{final_path.to_s} root: #{@root_dir.to_s}"

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
			image = request_state.images[@image_name] or raise MissingStatementError, "could not find '#{@image_name}' image"
			path = final_path(request_state)

			log.info "storing '#{@image_name}' in file '#{path}' (#{image.data.length}B)"
			path.open('w'){|io| io.write image.data}
		end
	end
	Handler::register_node_parser FileStore
end

