require 'httpimagestore/configuration/handler'
require 'httpimagestore/ruby_string_template'
require 'addressable/uri'
require 'base64'

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
			text = node.grab_values('text').first
			status, cache_control = *node.grab_attributes('status', 'cache-control')
			configuration.output = OutputText.new(text, status || 200, cache_control)
		end

		def initialize(text, status, cache_control)
			@text = RubyStringTemplate.new(text || fail("no text?!"))
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
		class OutputSpec < HandlerStatement
			include ConditionalInclusion
			attr_reader :image_name
			attr_reader :path_spec

			def initialize(global, image_name, scheme, host, port, path_spec, matcher)
				super(global)
				@image_name = image_name
				@scheme = scheme
				@host = host
				@port = port
				@path_spec = path_spec
				inclusion_matcher matcher
			end

			def store_path(request_state)
				store_path = request_state.images[@image_name].store_path or raise StorePathNotSetForImage.new(@image_name)
				return store_path unless @path_spec

				locals = {
					image_name: @image_name,
					path: store_path
				}

				rendered_path(request_state.with_locals(locals))
			end

			def store_url(request_state)
				url = request_state.images[@image_name].store_url or raise StoreURLNotSetForImage.new(@image_name)
				url = url.dup
				store_path = request_state.images[@image_name].store_path or raise StorePathNotSetForImage.new(@image_name)

				locals = {
					image_name: @image_name,
					path: store_path,
					url: url.to_s
				}
				locals[:scheme] = url.scheme if url.scheme
				locals[:host] = url.host if url.host
				locals[:port] = url.port if url.port

				request_state = request_state.with_locals(locals)

				# optional rewrites
				url.scheme = request_state.render_template(@scheme) if @scheme
				url.host = request_state.render_template(@host) if @host
				(url.host ||= 'localhost'; url.port = request_state.render_template(@port).to_i) if @port
				url.path = rendered_path(request_state).to_uri if @path_spec

				url.normalize
			end
		end

		def self.parse(configuration, node)
			nodes = node.values.empty? ? node.children : [node]
			output_specs = nodes.map do |node|
				image_name = node.grab_values('image name').first
				scheme, host, port, path_spec, if_image_name_on = *node.grab_attributes('scheme', 'host', 'port', 'path', 'if-image-name-on')
				matcher = InclusionMatcher.new(image_name, if_image_name_on)
				OutputSpec.new(configuration.global, image_name, scheme, host, port, path_spec, matcher)
			end

			configuration.output and raise StatementCollisionError.new(node, 'output')
			configuration.output = self.new(output_specs)
		end

		def initialize(output_specs)
			@output_specs = output_specs
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
			configuration.output = self.new(image_name, cache_control)
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

	class OutputDataURIImage < OutputImage
		def self.match(node)
			node.name == 'output_data_uri_image'
		end

		def realize(request_state)
			image = request_state.images[@name]
			fail "image '#{@name}' needs to be identified first to be used in data URI output" unless image.mime_type

			cache_control = @cache_control
			request_state.output do
				res['Cache-Control'] = cache_control if cache_control
				write 200, 'text/uri-list', "data:#{image.mime_type};base64,#{Base64.strict_encode64(image.data)}"
			end
		end
	end
	Handler::register_node_parser OutputDataURIImage

	class OutputStorePath < OutputMultiBase
		def self.match(node)
			node.name == 'output_store_path'
		end

		def realize(request_state)
			paths = @output_specs.select do |output_spec|
				output_spec.included?(request_state)
			end.map do |output_spec|
				output_spec.store_path(request_state)
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
			urls = @output_specs.select do |output_spec|
				output_spec.included?(request_state)
			end.map do |output_spec|
				output_spec.store_url(request_state)
			end

			request_state.output do
				write_url_list 200, urls
			end
		end
	end
	Handler::register_node_parser OutputStoreURL

	class OutputStoreURI < OutputMultiBase
		def self.match(node)
			node.name == 'output_store_uri'
		end

		def realize(request_state)
			urls = @output_specs.select do |output_spec|
				output_spec.included?(request_state)
			end.map do |output_spec|
				output_spec.store_url(request_state).path
			end

			request_state.output do
				write_url_list 200, urls
			end
		end
	end
	Handler::register_node_parser OutputStoreURI
end

