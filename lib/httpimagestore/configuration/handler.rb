require 'mime/types'
require 'digest/sha2'
require 'securerandom'

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

	class VariableNotDefinedError < ConfigurationError
		def initialize(name)
			super "variable '#{name}' not defined"
		end
	end

	class NoRequestBodyToGenerateMetaVariableError < ConfigurationError
		def initialize(meta_value)
			super "need not empty request body to generate value for '#{meta_value}'"
		end
	end

	class NoVariableToGenerateMetaVariableError < ConfigurationError
		def initialize(value_name, meta_value)
			super "need '#{value_name}' variable to generate value for '#{meta_value}'"
		end
	end

	class NoImageDataForVariableError < ConfigurationError
		def initialize(image_name, meta_value)
			super "image '#{image_name}' does not have data for variable '#{meta_value}'"
		end
	end

	class RequestState < Hash
		include ClassLogging

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

		def initialize(body = '', matches = {}, path = '', query_string = {}, memory_limit = MemoryLimit.new, headers = {})
			super() do |request_state, name|
				# note that request_state may be different object when useing with_locals that creates duplicate
				request_state[name] = request_state.generate_meta_variable(name) or raise VariableNotDefinedError.new(name)
			end

			self[:path] = path
			merge! matches
			self[:query_string_options] = query_string.sort.map{|kv| kv.join(':')}.join(',')

			log.debug "processing request with body length: #{body.bytesize} bytes and variables: #{map{|k,v| "#{k}: '#{v}'"}.join(', ')}"

			@body = body
			@images = Images.new(memory_limit)
			@memory_limit = memory_limit
			@output_callback = nil

			@headers = headers
		end

		attr_reader :body
		attr_reader :images
		attr_reader :memory_limit
		attr_reader :headers

		def with_locals(*locals)
			locals = locals.reduce{|a, b| a.merge(b)}
			log.debug "using additional local variables: #{locals}"
			self.dup.merge!(locals)
		end

		def output(&callback)
			@output_callback = callback
		end

		def output_callback
			@output_callback or fail 'no output callback'
		end

		def fetch_base_variable(name, base_name)
			fetch(base_name, nil) or generate_meta_variable(base_name) or raise NoVariableToGenerateMetaVariableError.new(base_name, name)
		end

		def generate_meta_variable(name)
			log.debug  "generating meta variable: #{name}"
			val = case name
			when :basename
				path = Pathname.new(fetch_base_variable(name, :path))
				path.basename(path.extname).to_s
			when :dirname
				Pathname.new(fetch_base_variable(name, :path)).dirname.to_s
			when :extension
				Pathname.new(fetch_base_variable(name, :path)).extname.delete('.')
			when :digest # deprecated
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s[0,16]
			when :input_digest
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s[0,16]
			when :input_sha256
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s
			when :input_image_width
				@images['input'].width or raise NoImageDataForVariableError.new('input', name)
			when :input_image_height
				@images['input'].height or raise NoImageDataForVariableError.new('input', name)
			when :input_image_mime_extension
				@images['input'].mime_extension or raise NoImageDataForVariableError.new('input', name)
			when :image_digest
				Digest::SHA2.new.update(@images[fetch_base_variable(name, :image_name)].data).to_s[0,16]
			when :image_sha256
				Digest::SHA2.new.update(@images[fetch_base_variable(name, :image_name)].data).to_s
			when :mimeextension # deprecated
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].mime_extension or raise NoImageDataForVariableError.new(image_name, name)
			when :image_mime_extension
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].mime_extension or raise NoImageDataForVariableError.new(image_name, name)
			when :image_width
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].width or raise NoImageDataForVariableError.new(image_name, name)
			when :image_height
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].height or raise NoImageDataForVariableError.new(image_name, name)
			when :uuid
				SecureRandom.uuid
			end
			if val
				log.debug  "generated meta variable '#{name}': #{val}"
			else
				log.debug  "could not generated meta variable '#{name}'"
			end
			val
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

	class Image < Struct.new(:data, :mime_type, :width, :height)
		include ImageMetaData
	end

	class InputSource
		def realize(request_state)
			request_state.body.empty? and raise ZeroBodyLengthError
			request_state.images['input'] = Image.new(request_state.body)
		end
	end

	class InclusionMatcher
		def initialize(value, template)
			@value = value
			@template = template.to_template if template
		end

		def included?(request_state)
			return true if not @template
			@template.render(request_state).split(',').include? @value
		end
	end

	class VariableMatcher
		def initialize(value)
			param_name, template = value.split(':', 2)
			@param_name = param_name.to_sym if param_name
			@template = template.to_template if template
		end

		def included?(request_state)
			return false if not @param_name
			return request_state[@param_name] == 'true' if not @template
			@template.render(request_state) == request_state[@param_name]
		rescue Configuration::VariableNotDefinedError
			false
		end
	end

	class HandlerStatement
		module ImageName
			attr_reader :image_name

			def initialize(global, *args)
				@image_name = args.pop

				super(global, *args)

				config_local :imagename, @image_name # deprecated
				config_local :image_name, @image_name
			end
		end

		module PathSpec
			attr_reader :path_spec

			def initialize(global, *args)
				@path_spec = args.pop
				super(global, *args)
			end

			def path_template
				@global.paths[@path_spec]
			end
		end

		module ConditionalInclusion
			def push_inclusion_matchers(*matchers)
				@matchers ||= []
				@matchers.push(*matchers)
				self
			end

			def included?(request_state)
				return true if not @matchers or @matchers.empty?
				@matchers.any? do |matcher|
					matcher.included?(request_state)
				end
			end

			def excluded?(request_state)
				not included? request_state
			end
		end

		def initialize(global, *args)
			@global = global
			@config_locals = {}
			@module_args = args
		end

		attr_reader :config_locals
		def config_local(name, value)
			@config_locals[name] = value
		end

		def path_template(path_spec)
			@global.paths[path_spec]
		end
	end

	class SourceStoreBase < HandlerStatement
		include ImageName
		include PathSpec
		include ConditionalInclusion

		def initialize(global, image_name, matcher, path_spec)
			super(global, image_name, path_spec, matcher)
		end

		private

		def put_sourced_named_image(request_state)
			rendered_path = path_template.render(request_state.with_locals(config_locals))

			image = yield @image_name, rendered_path

			image.source_path = rendered_path
			request_state.images[@image_name] = image
		end

		def get_named_image_for_storage(request_state)
			image = request_state.images[@image_name]
			rendered_path = path_template.render(request_state.with_locals(config_locals))
			image.store_path = rendered_path

			yield @image_name, image, rendered_path
		end
	end

	class Matcher
		def initialize(names, debug_type = '', debug_value = '', &matcher)
			@names = names
			@matcher = matcher
			@debug_type = debug_type
			@debug_value = case debug_value
			when Regexp
				"/#{debug_value.source}/"
			else
				debug_value.inspect
			end
		end

		attr_reader :names
		attr_reader :matcher

		def to_s
			if @names.empty?
				"#{@debug_type}(#{@debug_value})"
			else
				"#{@debug_type}(#{@names.join(',')} => #{@debug_value})"
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
					:sources,
					:processors,
					:stores,
					:output
				).new

			handler_configuration.global = configuration
			handler_configuration.http_method = node.name
			handler_configuration.uri_matchers = node.values.map do |matcher|
				case matcher
				# URI matchers
				when %r{^:([^/]+)/(.*)/$} # :foobar/.*/
					name = $1.to_sym
					_regexp = Regexp.new($2)
					regexp = Regexp.new("(#{$2})")
					Matcher.new([name], 'Regexp', _regexp) do
						regexp
					end
				when %r{^/(.*)/$} # /.*/
					regexp = $1
					_regexp = Regexp.new($1)
					names = Regexp.new($1).names.map{|n| n.to_sym}
					Matcher.new(names, 'Regexp', _regexp) do
						-> {
							matchdata = env["PATH_INFO"].match(/\A\/(?<_match_>#{regexp})(?<_tail_>(?:\/|\z))/)

							next false unless matchdata

							path, *vars = matchdata.captures

							env["SCRIPT_NAME"] += "/#{path}"
							env["PATH_INFO"] = "#{vars.pop}#{matchdata.post_match}"

							captures.push(*vars)
						}
					end
				when /^:(.+)\?(.*)$/ # :foo?bar
					name = $1.to_sym
					default = $2
					Matcher.new([name], 'SegmentDefault', "<segment>|#{default}") do
						->{match(name) || captures.push(default)}
					end
				when /^:(.+)$/ # :foobar
					name = $1.to_sym
					Matcher.new([name], 'Segment', '<segment>') do
						name
					end
				# Query string matchers
				when /^\&([^=]+)=(.+)$/# ?foo=bar
					name = $1.to_sym
					value = $2
					Matcher.new([name], 'QueryKeyValue', "#{name}=#{value}") do
						->{req.GET[name.to_s] && req.GET[name.to_s] == value && captures.push(req.GET[name.to_s])}
					end
				when /^\&:(.+)\?(.*)$/# &:foo?bar
					name = $1.to_sym
					default = $2
					Matcher.new([name], 'QueryKeyDefault', "#{name}=<key>|#{default}") do
						->{captures.push(req.GET[name.to_s] || default)}
					end
				when /^\&:(.+)$/# &:foo
					name = $1.to_sym
					Matcher.new([name], 'QueryKey', "#{name}=<key>") do
						->{req.GET[name.to_s] && captures.push(req.GET[name.to_s])}
					end
				# Literal URI segment matcher
				else # foobar
					Matcher.new([], "Literal", matcher) do
						Regexp.escape(matcher)
					end
				end
			end
			handler_configuration.sources = []
			handler_configuration.processors = []
			handler_configuration.stores = []
			handler_configuration.output = nil

			node.grab_attributes

			if handler_configuration.http_method != 'get'
				handler_configuration.sources << InputSource.new
			end

			configuration.handlers << handler_configuration

			self.new(handler_configuration).parse(node)

			handler_configuration.output = OutputOK.new unless handler_configuration.output
		end

		def self.post(configuration)
			log.warn 'no handlers configured' if configuration.handlers.empty?
		end
	end
	RequestState.logger = Global.logger_for(RequestState)

	Global.register_node_parser Handler
end

