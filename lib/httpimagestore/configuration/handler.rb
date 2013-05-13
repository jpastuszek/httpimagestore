module Configuration
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

		def initialize(root_configuration, handler_configuration, matchers, node)
			@root_configuration = root_configuration
			super handler_configuration
			handler_configuration.matchers = matchers
			handler_configuration.image_source = []
			handler_configuration.stor = []
			handler_configuration.output = []
			parse node
		end
	end
	Global.register_node_parser Handler
end

