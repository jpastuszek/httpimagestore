module Configuration
	class ImageNotLoadedError < ConfigurationError
		def initialize(image_name)
			super "image '#{image_name}' not loaded"
		end
	end

	class RequestState
		def initialize(body = '', locals = {})
			@images = Hash.new{|hash, image_name| raise ImageNotLoadedError.new(image_name)}
			@body = body
			@locals = locals
			@output_callback = nil
		end

		attr_reader :images
		attr_reader :body
		attr_reader :locals

		def output(&callback)
			@output_callback = callback
		end

		def output_callback
			@output_callback or fail 'no output callback'
		end
	end

	module ImageMetaData
		attr_accessor :source_path
		attr_accessor :source_url
		attr_accessor :store_path
		attr_accessor :store_url
	end

	class Image < Struct.new(:data, :mime_type)
		include ImageMetaData
	end

	class InputSource
		def realize(request_state)
			request_state.images['input'] = Image.new(request_state.body)
		end
	end

	class OutputOK
		def realize(request_state)
			request_state.output do
				write_plain 200, 'OK'
			end
		end
	end

	class Handler < Scope
		def self.match(node)
			node.name == 'put' or
			node.name == 'post' or
			node.name == 'get'
		end

		def self.pre(configuration)
			configuration.handlers ||= []
		end

		def self.parse(configuration, node)
			handler_configuration = 
				Struct.new(
					:global,
					:http_method,
					:uri_matchers,
					:image_sources,
					:stores,
					:output
				).new

			handler_configuration.global = configuration
			handler_configuration.http_method = node.name
			handler_configuration.uri_matchers = node.values.map{|matcher| matcher =~ /^:/ ? matcher.sub(/^:/, '').to_sym : matcher}
			handler_configuration.image_sources = []
			handler_configuration.stores = []
			handler_configuration.output = nil

			if handler_configuration.http_method != 'get'
				handler_configuration.image_sources << InputSource.new
			end

			configuration.handlers << handler_configuration

			self.new(handler_configuration).parse(node)

			handler_configuration.output = OutputOK.new unless handler_configuration.output
		end

		def self.post(configuration)
			log.warn 'no handlers configured' if configuration.handlers.empty?
		end
	end
	Global.register_node_parser Handler
end

