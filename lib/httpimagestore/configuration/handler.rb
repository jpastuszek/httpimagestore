module Configuration
	Image = Class.new Struct.new(:data, :mime_type)

	class InputSource
		def realize(locals)
			@data = locals[:request_body] unless @data
			(locals[:images] ||= {})['input'] = Image.new(@data)
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

			configuration.handler ||= []
			handler_configuration = OpenStruct.new

			configuration.handler << handler_configuration
			self.new(configuration, handler_configuration, matchers, node)
		end

		def initialize(global_configuration, handler_configuration, matchers, node)
			super handler_configuration

			# let parsers access global configuration
			handler_configuration.global = global_configuration

			handler_configuration.matchers = matchers
			handler_configuration.image_source = []
			handler_configuration.store = []
			handler_configuration.output = []

			if matchers.first != 'get'
				handler_configuration.image_source << InputSource.new
			end

			parse node
		end
	end
	Global.register_node_parser Handler
end

