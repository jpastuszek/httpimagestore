require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler'
require 'pathname'

module Configuration
	class FileStorageOutsideOfRootDirError < ConfigurationError
		def initialize(image_name, file_path)
			super "error while processing image '#{image_name}': file storage path '#{file_path.to_s}' outside of root direcotry"
		end
	end

	class NoSuchFileError < ConfigurationError
		def initialize(image_name, file_path)
			super "error while processing image '#{image_name}': file '#{file_path.to_s}' not found"
		end
	end

	class FileSourceStoreBase < SourceStoreBase
		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first
			node.required_attributes('root', 'path')
			root_dir, path_spec, if_image_name_on = *node.grab_attributes('root', 'path', 'if-image-name-on')
			matcher = InclusionMatcher.new(image_name, if_image_name_on)

			self.new(
				configuration.global, 
				image_name, 
				matcher,
				root_dir, 
				path_spec 
			)
		end

		def initialize(global, image_name, matcher, root_dir, path_spec)
			super global, image_name, matcher
			@root_dir = Pathname.new(root_dir).cleanpath
			@path_spec = path_spec
		end

		def storage_path(rendered_path)
			path = Pathname.new(rendered_path)

			storage_path = (@root_dir + path).cleanpath
			storage_path.to_s =~ /^#{@root_dir.to_s}/ or raise FileStorageOutsideOfRootDirError.new(@image_name, path)

			storage_path
		end
	end

	class FileSource < FileSourceStoreBase
		include ClassLogging

		def self.match(node)
			node.name == 'source_file'
		end

		def self.parse(configuration, node)
			configuration.image_sources << super
		end

		def realize(request_state)
			put_sourced_named_image(request_state) do |image_name, rendered_path|
				storage_path = storage_path(rendered_path)

				log.info "sourcing '#{image_name}' from file '#{storage_path}'"
				begin
					image = Image.new(storage_path.open('r'){|io| io.read})
					image.source_url = "file://#{rendered_path}"
					image
				rescue Errno::ENOENT
					raise NoSuchFileError.new(image_name, rendered_path)
				end
			end
		end
	end
	Handler::register_node_parser FileSource
	
	class FileStore < FileSourceStoreBase
		include ClassLogging

		def self.match(node)
			node.name == 'store_file'
		end

		def self.parse(configuration, node)
			configuration.stores << super
		end

		def realize(request_state)
			get_named_image_for_storage(request_state) do |image_name, image, rendered_path|
				storage_path = storage_path(rendered_path)

				image.store_url = "file://#{rendered_path.to_s}"

				log.info "storing '#{image_name}' in file '#{storage_path}' (#{image.data.length} bytes)"
				storage_path.open('w'){|io| io.write image.data}
			end
		end
	end
	Handler::register_node_parser FileStore
end

