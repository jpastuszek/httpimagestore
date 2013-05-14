module Configuration
	CouldNotFindImageError = Class.new MissingStatementError

	class RequestState
		def initialize(body = '', locals = {})
			@images = Hash.new{|hash, image_name| raise CouldNotFindImageError, "could not find '#{image_name}' image"}
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

	Image = Class.new Struct.new(:data, :mime_type)

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
			http_method = node.name
			uri_matchers = node.values.map{|matcher| matcher =~ /^:/ ? matcher.sub(/^:/, '').to_sym : matcher}

			handler_configuration = OpenStruct.new

			configuration.handlers << handler_configuration
			self.new(configuration, handler_configuration, http_method, uri_matchers, node)
		end

		def self.post(configuration)
			log.warn 'no handlers configured' if configuration.handlers.empty?
		end

		def initialize(global_configuration, handler_configuration, http_method, uri_matchers, node)
			super handler_configuration

			# let parsers access global configuration
			handler_configuration.global = global_configuration

			handler_configuration.http_method = http_method
			handler_configuration.uri_matchers = uri_matchers
			handler_configuration.image_sources = []
			handler_configuration.stores = []
			handler_configuration.output = nil

			if http_method != 'get'
				handler_configuration.image_sources << InputSource.new
			end

			parse node

			handler_configuration.output = OutputOK.new unless handler_configuration.output
		end
	end
	Global.register_node_parser Handler
end

