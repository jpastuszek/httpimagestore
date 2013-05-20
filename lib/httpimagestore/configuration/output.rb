require 'httpimagestore/configuration/handler'

module Configuration
	class StorePathNotSetForImage < ConfigurationError
		def initialize(image_name)
			super "store path not set for image '#{image_name}'"
		end
	end

	class StoreURLNotSetForImage < ConfigurationError
		def initialize(image_name)
			super "store URL not set for image '#{image_name}'"
		end
	end

	class OutputMultiBase
		def self.parse(configuration, node)
			names =
				unless node.values.empty?
					[node.grab_values('image name').first]
				else
					node.children.map do |node|
						node.grab_values('image name').first
					end
				end
			configuration.output and raise StatementCollisionError.new(node, 'output')
			configuration.output = self.new(names)
		end

		def initialize(names)
			@names = names
		end
	end
	
	class OutputImage
		include ClassLogging

		def self.match(node)
			node.name == 'output_image'
		end

		def self.parse(configuration, node)
			configuration.output and raise StatementCollisionError.new(node, 'output')
			image_name = node.grab_values('image name').first
			configuration.output = OutputImage.new(image_name)
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

	class OutputStorePath < OutputMultiBase
		def self.match(node)
			node.name == 'output_store_path'
		end

		def realize(request_state)
			paths = @names.map do |name|
				request_state.images[name].store_path or raise StorePathNotSetForImage.new(name)
			end

			request_state.output do
				write_plain 200, paths
			end
		end
	end
	Handler::register_node_parser OutputStorePath

	class OutputStoreURL < OutputMultiBase
		def self.match(node)
			node.name == 'output_store_url'
		end

		def realize(request_state)
			urls = @names.map do |name|
				request_state.images[name].store_url or raise StoreURLNotSetForImage.new(name)
			end

			request_state.output do
				write_plain 200, urls
			end
		end
	end
	Handler::register_node_parser OutputStoreURL
end

