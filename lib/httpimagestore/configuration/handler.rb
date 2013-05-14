module Configuration
	class RequestState
		def initialize(body, locals = {})
			@images = {}
			@body = body
			@locals = locals
		end

		attr_reader :images
		attr_reader :body
		attr_reader :locals
	end

	Image = Class.new Struct.new(:data, :mime_type)

	class InputSource
		def realize(request_state)
			request_state.images['input'] = Image.new(request_state.body)
		end
	end

	class Handler < Scope
		def self.match(node)
			node.name == 'put' or
			node.name == 'post' or
			node.name == 'get'
		end

		def self.parse(configuration, node)
			matchers = [
				node.name,
				*node.values.map{|matcher| matcher =~ /^:/ ? matcher.sub(/^:/, '').to_sym : matcher}
			]

			configuration.handlers ||= []
			handler_configuration = OpenStruct.new

			configuration.handlers << handler_configuration
			self.new(configuration, handler_configuration, matchers, node)
		end

		def initialize(global_configuration, handler_configuration, matchers, node)
			super handler_configuration

			# let parsers access global configuration
			handler_configuration.global = global_configuration

			handler_configuration.matchers = matchers
			handler_configuration.image_sources = []
			handler_configuration.stores = []
			handler_configuration.outputs = []

			if matchers.first != 'get'
				handler_configuration.image_sources << InputSource.new
			end

			parse node
		end
	end
	Global.register_node_parser Handler
end

