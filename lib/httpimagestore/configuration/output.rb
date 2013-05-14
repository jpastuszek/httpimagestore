module Configuration
	class OutputImage
		def self.match(node)
			node.name == 'output_image'
		end

		def self.parse(configuration, node)
			name = node.values.first or raise MissingArgumentError, 'input image name'
			configuration.output and raise DuplicateArgumentError, 'only one output can be specified'
			configuration.output = OutputImage.new(name)
		end

		def initialize(name)
			@name = name
		end

		def realize(request_state)
			image = request_state.images[@name] or raise MissingStatementError, "image '#{@name}' not found"
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
end

