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

	class OutputText
		def self.match(node)
			node.name == 'output_text'
		end

		def self.parse(configuration, node)
			configuration.output and raise StatementCollisionError.new(node, 'output')
			text = RubyStringTemplate.new(node.grab_values('text').first)
			status, cache_control = *node.grab_attributes('status', 'cache-control')
			configuration.output = OutputText.new(text, status || 200, cache_control)
		end

		def initialize(text, status, cache_control)
			@text = text || '?!'
			@status = status || 200
			@cache_control = cache_control
		end

		def realize(request_state)
			# make sure variables are available in request context
			status = @status
			text = @text.render(request_state)
			cache_control = @cache_control
			request_state.output do
				res['Cache-Control'] = cache_control if cache_control
				write_plain status.to_i, text.to_s
			end
		end
	end

	class OutputOK < OutputText
		def self.match(node)
			node.name == 'output_ok'
		end

		def self.parse(configuration, node)
			configuration.output and raise StatementCollisionError.new(node, 'output')
			cache_control = node.grab_attributes('cache-control').first
			configuration.output = OutputOK.new(cache_control)
		end

		def initialize(cache_control = nil)
			super 'OK', 200, cache_control
		end
	end
	Handler::register_node_parser OutputText

	class OutputMultiBase
		class ImageName < String
			include ConditionalInclusion

			def initialize(name, matcher)
				super name
				inclusion_matcher matcher
			end
		end

		def self.parse(configuration, node)
			nodes = node.values.empty? ? node.children : [node]
			names = nodes.map do |node|
				image_name = node.grab_values('image name').first
				matcher = InclusionMatcher.new(image_name, node.grab_attributes('if-image-name-on').first)
				ImageName.new(image_name, matcher)
			end

			configuration.output and raise StatementCollisionError.new(node, 'output')
			configuration.output = self.new(names)
		end

		def initialize(names)
			@names = names
		end
	end
	Handler::register_node_parser OutputOK

	class OutputImage
		include ClassLogging

		def self.match(node)
			node.name == 'output_image'
		end

		def self.parse(configuration, node)
			configuration.output and raise StatementCollisionError.new(node, 'output')
			image_name = node.grab_values('image name').first
			cache_control = node.grab_attributes('cache-control').first
			configuration.output = OutputImage.new(image_name, cache_control)
		end

		def initialize(name, cache_control)
			@name = name
			@cache_control = cache_control
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

			cache_control = @cache_control
			request_state.output do
				res['Cache-Control'] = cache_control if cache_control
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
			paths = @names.select do |name|
				name.included?(request_state)
			end.map do |name|
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
			urls = @names.select do |name|
				name.included?(request_state)
			end.map do |name|
				request_state.images[name].store_url or raise StoreURLNotSetForImage.new(name)
			end

			request_state.output do
				write_url_list 200, urls
			end
		end
	end
	Handler::register_node_parser OutputStoreURL
end

