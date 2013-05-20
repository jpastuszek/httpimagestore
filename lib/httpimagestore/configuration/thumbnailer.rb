require 'unicorn-cuba-base'
require 'httpthumbnailer-client'
require 'httpimagestore/ruby_string_template'
require 'httpimagestore/configuration/handler'

module Configuration
	class Thumnailer
		include ClassLogging

		def self.match(node)
			node.name == 'thumbnailer'
		end

		def self.parse(configuration, node)
			configuration.thumbnailer and raise StatementCollisionError.new(node, 'thumbnailer')
			configuration.thumbnailer = HTTPThumbnailerClient.new(node.attribute('url') || raise(NoAttributeError.new(node, 'url')))
		end

		def self.post(configuration)
			if not configuration.thumbnailer
				configuration.thumbnailer = HTTPThumbnailerClient.new(configuration.defaults[:thumbnailer_url] || 'http://localhost:3100')
			end
			log.info "using thumbnailer at #{configuration.thumbnailer.server_url}"
		end
	end
	Global.register_node_parser Thumnailer

	class NoValueForSpecTemplatePlaceholerError < ConfigurationError
		def initialize(image_name, spec_name, value_name, template)
			super "cannot generate specification for thumbnail '#{image_name}': cannot generate value for attribute '#{spec_name}' from template '#{template}': no value for \#{#{value_name}}"
		end
	end

	class Thumbnail
		include ClassLogging

		class ThumbnailingError < RuntimeError
			def initialize(input_image_name, output_image_name, remote_error)
				@remote_error = remote_error
				super "thumbnailing of '#{input_image_name}' into '#{output_image_name}' failed: #{remote_error.message}"
			end

			attr_reader :remote_error
		end

		class ThumbnailSpec
			class Spec < RubyStringTemplate
				def initialize(image_name, sepc_name, template)
					super(template) do |locals, name|
						locals[name] or raise NoValueForSpecTemplatePlaceholerError.new(image_name, sepc_name, name, template)
					end
				end
			end

			def initialize(image_name, method, width, height, format, options = {}, exclusion_matcher = nil)
				@image_name = image_name
				@method = Spec.new(image_name, 'method', method)
				@width = Spec.new(image_name, 'width', width)
				@height = Spec.new(image_name, 'height', height)
				@format = Spec.new(image_name, 'format', format)
				@options = options.inject({}){|h, v| h[v.first] = Spec.new(image_name, v.first, v.last); h}
				@exclusion_matcher = exclusion_matcher
			end

			def excluded?(request_state)
				return false unless @exclusion_matcher
				@exclusion_matcher.excluded?(request_state)
			end

			attr_reader :image_name

			def render(locals = {})
				options = @options.inject({}){|h, v| h[v.first] = v.last.render(locals); h}
				nested_options = options['options'] ? Hash[options.delete('options').to_s.split(',').map{|pair| pair.split(':', 2)}] : {}
				{
					@image_name =>
						[
							@method.render(locals),
							@width.render(locals),
							@height.render(locals),
							@format.render(locals),
							nested_options.merge(options)
						]
				}
			end
		end

		def self.match(node)
			node.name == 'thumbnail'
		end

		def self.parse(configuration, node)
			source_image_name = node.values.first or raise NoValueError.new(node, 'source image name')
			use_multipart_api = false

			nodes =
				if node.values.drop(1).empty?
					use_multipart_api = true
					node.children
				else
					[node]
				end

			nodes.empty? and raise NoValueError.new(node, 'thumbnail image name')
			specs = nodes.map do |node|
				attributes = node.attributes.dup

				image_name = node.values.last or raise NoValueError.new(node, 'thumbnail image name')
				if_image_name_on = attributes.delete("if_image_name_on")

				ThumbnailSpec.new(
					image_name,
					attributes.delete("operation") || 'fit',
					attributes.delete("width") || 'input',
					attributes.delete("height") || 'input',
					attributes.delete("format") || 'jpeg',
					attributes,
					OptionalExclusionMatcher.new(image_name, if_image_name_on)
				)
			end

			configuration.image_sources << self.new(configuration.global, source_image_name, specs, use_multipart_api)
		end

		def initialize(global, source_image_name, specs, use_multipart_api)
			@global = global
			@source_image_name = source_image_name
			@specs = specs
			@use_multipart_api = use_multipart_api
		end

		def realize(request_state)
			client = @global.thumbnailer or fail 'thumbnailer configuration'

			rendered_specs = {}
			@specs.select do |spec|
				not spec.excluded?(request_state)
			end.each do |spec|
				rendered_specs.merge! spec.render(request_state.locals)
			end
			source_image = request_state.images[@source_image_name]

			thumbnails = {}
			input_mime_type = nil

			if @use_multipart_api
				log.info "thumbnailing '#{@source_image_name}' to multiple specs: #{rendered_specs}"

				thumbnails = client.thumbnail(source_image.data) do
					rendered_specs.values.each do |spec|
						thumbnail(*spec)
					end
				end
				input_mime_type = thumbnails.input_mime_type

				thumbnails = Hash[rendered_specs.keys.zip(thumbnails)]

				thumbnails.each do |name, thumbnail|
					raise ThumbnailingError.new(@source_image_name, name, thumbnail) if thumbnail.kind_of? HTTPThumbnailerClient::ThumbnailingError
				end
			else
				name, rendered_spec = *rendered_specs.first
				log.info "thumbnailing '#{@source_image_name}' to '#{name}' with spec: #{rendered_spec}"

				begin
					thumbnail = client.thumbnail(source_image.data, *rendered_spec)
					input_mime_type = thumbnail.input_mime_type
					thumbnails[name] = thumbnail
				rescue HTTPThumbnailerClient::HTTPThumbnailerClientError => error
					raise ThumbnailingError.new(@source_image_name, name, error)
				end
			end

			# copy input source path and url
			thumbnails.each do |name, thumbnail|
				thumbnail.extend ImageMetaData
				thumbnail.source_path = source_image.source_path
				thumbnail.source_url = source_image.source_url
			end

			# update input image mime type from httpthumbnailer provided information
			source_image.mime_type = input_mime_type unless source_image.mime_type

			request_state.images.merge! thumbnails
		end
	end
	Handler::register_node_parser Thumbnail
end

