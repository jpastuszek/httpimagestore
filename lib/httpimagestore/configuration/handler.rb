require 'httpimagestore/configuration/request_state'
require 'httpimagestore/ruby_string_template'

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

	class Matcher
		def initialize(names, debug_type = '', debug_value = '', &matcher)
			@names = names
			@matcher = matcher
			@debug_type = debug_type
			@debug_value = case debug_value
			when Regexp
				"/#{debug_value.source}/"
			when nil
				nil
			else
				debug_value.to_s
			end
		end

		attr_reader :names
		attr_reader :matcher

		def to_s
			if @debug_value
				if @names.empty?
					"#{@debug_type}(#{@debug_value})"
				else
					"#{@debug_type}(#{@names.join(',')} => #{@debug_value})"
				end
			else
				@debug_type
			end
		end
	end

	class Handler < Scope
		class HandlerConfiguration
			def initialize(global, http_method, uri_matchers)
				@global = global
				@http_method = http_method
				@uri_matchers = uri_matchers
				@validators = []
				@sources = []
				@processors = []
				@stores = []
				@output = nil
			end

			attr_accessor :global, :http_method, :uri_matchers, :validators, :sources, :processors, :stores, :output

			def to_s
				"#{@http_method} #{@uri_matchers.join(', ')}"
			end
		end

		def self.match(node)
			node.name == 'put' or
			node.name == 'post' or
			node.name == 'get'
		end

		def self.pre(configuration)
			configuration.handlers ||= []
		end

		def self.parse(configuration, node)
			uri_matchers = node.values.map do |matcher|
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
					Matcher.new([name], 'QueryKeyValue', "#{value}") do
						->{req.GET[name.to_s] && req.GET[name.to_s] == value && captures.push(req.GET[name.to_s])}
					end
				when /^\&:(.+)\?(.*)$/# &:foo?bar
					name = $1.to_sym
					default = $2
					Matcher.new([name], 'QueryKeyDefault', "<key>|#{default}") do
						->{captures.push(req.GET[name.to_s] || default)}
					end
				when /^\&:(.+)$/# &:foo
					name = $1.to_sym
					Matcher.new([name], 'QueryKey', "<key>") do
						->{req.GET[name.to_s] && captures.push(req.GET[name.to_s])}
					end
				# Literal URI segment matcher
				else # foobar
					Matcher.new([], matcher, nil) do
						Regexp.escape(matcher)
					end
				end
			end

			handler_configuration = HandlerConfiguration.new(configuration, node.name, uri_matchers)

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

	class OutputText < Scope
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

	Global.register_node_parser Handler
	Handler::register_node_parser OutputText
	Handler::register_node_parser OutputOK
end

