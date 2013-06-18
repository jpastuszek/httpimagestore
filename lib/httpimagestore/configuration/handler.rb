require 'mime/types'
require 'httpimagestore/memory_limit'

module Configuration
	class ImageNotLoadedError < ConfigurationError
		def initialize(image_name)
			super "image '#{image_name}' not loaded"
		end
	end

	class ZeroBodyLengthError < ConfigurationError
		def initialize
			super 'empty body - expected image data'
		end
	end

	class RequestState
		class Images < Hash
			def initialize(memory_limit)
				@memory_limit = memory_limit
				super
			end

			def []=(name, image)
				if member?(name)
					@memory_limit.return fetch(name).data.bytesize
				end
				super
			end

			def [](name)
				fetch(name){|image_name| raise ImageNotLoadedError.new(image_name)}
			end
		end
		
		def initialize(body = '', locals = {}, memory_limit = MemoryLimit.new)
			@images = Images.new(memory_limit)
			@locals = {body: body}.merge(locals)
			@memory_limit = memory_limit
			@output_callback = nil
		end

		attr_reader :images
		attr_reader :locals
		attr_reader :memory_limit

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

		def mime_extension
			return nil unless mime_type
			mime = MIME::Types[mime_type].first
			mime.extensions.select{|e| e.length == 3}.first or mime.extensions.first
		end
	end

	class Image < Struct.new(:data, :mime_type)
		include ImageMetaData
	end

	class InputSource
		def realize(request_state)
			request_state.locals[:body].empty? and raise ZeroBodyLengthError
			request_state.images['input'] = Image.new(request_state.locals[:body])
		end
	end

	class OutputOK
		def realize(request_state)
			request_state.output do
				write_plain 200, 'OK'
			end
		end
	end

	class InclusionMatcher
		def initialize(value, template)
			@value = value
			@template = RubyStringTemplate.new(template) if template
		end

		def included?(request_state)
			return true if not @template
			@template.render(request_state.locals).split(',').include? @value
		end
	end

	module ConditionalInclusion
		def inclusion_matcher(matcher)
			(@matchers ||= []) << matcher if matcher
		end

		def included?(request_state)
			return true unless @matchers
			@matchers.any? do |matcher|
				matcher.included?(request_state)
			end
		end

		def excluded?(request_state)
			not included? request_state
		end
	end

	class SourceStoreBase
		include ConditionalInclusion

		def initialize(global, image_name, matcher)
			@global = global
			@image_name = image_name
			@locals = {imagename: @image_name}
			inclusion_matcher matcher
		end

		private

		attr_accessor :image_name

		def local(name, value)
			@locals[name] = value
		end

		def rendered_path(request_state)
			path = @global.paths[@path_spec]
			Pathname.new(path.render(@locals.merge(request_state.locals))).cleanpath.to_s
		end

		def put_sourced_named_image(request_state)
			rendered_path = rendered_path(request_state)

			image = yield @image_name, rendered_path

			image.source_path = rendered_path
			request_state.images[@image_name] = image
		end

		def get_named_image_for_storage(request_state)
			image = request_state.images[@image_name]
			local :mimeextension, image.mime_extension

			rendered_path = rendered_path(request_state)
			image.store_path = rendered_path

			yield @image_name, image, rendered_path
		end
	end

	class Matcher
		def initialize(name, &matcher)
			@name = name
			@matcher = matcher
		end

		attr_reader :name
		attr_reader :matcher
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
			handler_configuration.uri_matchers = node.values.map do |matcher|
				case matcher
				when %r{^:[^/]+/.*/$}
					name, regexp = *matcher.match(%r{^:([^/]+)/(.*)/$}).captures
					Matcher.new(name.to_sym) do
						Regexp.new("(#{regexp})")
					end
				when /^:.+\?$/
					name = matcher.sub(/^:(.+)\?$/, '\1').to_sym
					Matcher.new(name) do
						->{match(name) || captures.push('')}
					end
				when /^:/
					name = matcher.sub(/^:/, '').to_sym
					Matcher.new(name) do
						name
					end
				else
					Matcher.new(nil) do
						matcher
					end
				end
			end
			handler_configuration.image_sources = []
			handler_configuration.stores = []
			handler_configuration.output = nil

			node.grab_attributes

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

