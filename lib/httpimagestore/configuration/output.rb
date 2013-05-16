require 'httpimagestore/configuration/handler'

module Configuration
	class StorePathNotSetForImage < ConfigurationError
		def initialize(image_name)
			super "store path not set for image '#{image_name}'"
		end
	end
	
	class OutputImage
		include ClassLogging

		def self.match(node)
			node.name == 'output_image'
		end

		def self.parse(configuration, node)
			name = node.values.first or raise NoValueError.new(node, 'image name')
			configuration.output and raise StatementCollisionError.new(node, 'output')
			configuration.output = OutputImage.new(name)
		end

		def initialize(name)
			@name = name
		end

		def realize(request_state)
			image = request_state.images[@name]
			mime_type = 
				if image.mime_type
					image.mime_type
				else
					log.warn "image '#{@name}' has no mime type; sending 'application/octet-stream' content type"
					'application/octet-stream'
				end

			request_state.output do
				write 200, mime_type, image.data
			end
		end
	end
	Handler::register_node_parser OutputImage

	class OutputStorePath
		def self.match(node)
			node.name == 'output_store_path'
		end

		def self.parse(configuration, node)
			image_names =
				unless node.values.empty?
					[node.values.first]
				else
					node.children.map do |node|
						node.values.first or raise NoValueError.new(node, 'image name')
					end
				end

			configuration.output and raise StatementCollisionError.new(node, 'output')
			configuration.output = OutputStorePath.new(image_names)
		end

		def initialize(image_names)
			@image_names = image_names
		end

		def realize(request_state)
			paths = @image_names.map do |name|
				request_state.images[name].store_path or raise StorePathNotSetForImage.new(name)
			end

			request_state.output do
				write_plain 200, paths
			end
		end
	end
	Handler::register_node_parser OutputStorePath
end

