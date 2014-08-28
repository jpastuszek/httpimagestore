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
			node.required_attributes('url')
			configuration.thumbnailer = HTTPThumbnailerClient.new(node.grab_attributes('url').first)
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

	class NoSpecSelectedError < RuntimeError
		def initialize(specs)
			super "no thumbnailing specs were selected, please use at least one of: #{specs.join(', ')}"
		end
	end

	class Thumbnail < HandlerStatement
		include ClassLogging

		extend Stats
		def_stats(
			:total_thumbnail_requests,
			:total_thumbnail_requests_bytes,
			:total_thumbnail_thumbnails,
			:total_thumbnail_thumbnails_bytes
		)

		class ThumbnailingError < RuntimeError
			def initialize(input_image_name, output_image_name, remote_error)
				@remote_error = remote_error
				if output_image_name
					super "thumbnailing of '#{input_image_name}' into '#{output_image_name}' failed: #{remote_error.message}"
				else
					super "thumbnailing of '#{input_image_name}' failed: #{remote_error.message}"
				end
			end

			attr_reader :remote_error
		end

		class ThumbnailSpec < HandlerStatement
			include ImageName
			include ConditionalInclusion

			def initialize(image_name, method, width, height, format, options = {}, matcher = nil)
				super(nil, image_name, matcher)
				@method = method.to_template.with_missing_resolver{|locals, key| raise NoValueForSpecTemplatePlaceholerError.new(image_name, 'method', key, method)}
				@width =  width.to_s.to_template.with_missing_resolver{|locals, key| raise NoValueForSpecTemplatePlaceholerError.new(image_name, 'width', key, width)}
				@height = height.to_s.to_template.with_missing_resolver{|locals, key| raise NoValueForSpecTemplatePlaceholerError.new(image_name, 'height', key, height)}
				@format = format.to_template.with_missing_resolver{|locals, key| raise NoValueForSpecTemplatePlaceholerError.new(image_name, 'format', key, format)}

				@options = options.merge(options) do |option, old, template|
					template.to_s.to_template.with_missing_resolver{|locals, field| raise NoValueForSpecTemplatePlaceholerError.new(image_name, option, field, template)}
				end
			end

			def render(locals = {})
				options = @options.inject({}){|h, v| h[v.first] = v.last.render(locals); h}
				nested_options = options['options'] ? Hash[options.delete('options').to_s.split(',').map{|pair| pair.split(':', 2)}] : {}
				{
					image_name =>
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
			use_multipart_api = node.values.length == 1 ? true : false

			nodes = use_multipart_api ?  node.children : [node]
			source_image_name = use_multipart_api ? node.grab_values('source image name').first : nil # parsed later

			nodes.empty? and raise NoValueError.new(node, 'thumbnail image name')
			matcher = nil

			specs = nodes.map do |node|
				if use_multipart_api
					image_name = node.grab_values('thumbnail image name').first
				else
					source_image_name, image_name = *node.grab_values('source image name', 'thumbnail image name')
				end

				operation, width, height, format, if_image_name_on, remaining = *node.grab_attributes_with_remaining('operation', 'width', 'height', 'format', 'if-image-name-on')

				matcher = InclusionMatcher.new(image_name, if_image_name_on) if if_image_name_on

				ThumbnailSpec.new(
					image_name,
					operation || 'fit',
					width || 'input',
					height || 'input',
					format || 'input',
					remaining || {},
					matcher
				)
			end

			matcher = InclusionMatcher.new(source_image_name, node.grab_attributes('if-image-name-on').first) if use_multipart_api

			configuration.processors << self.new(
				configuration.global,
				source_image_name,
				specs,
				use_multipart_api,
				matcher
			)
		end

		include ConditionalInclusion

		def initialize(global, source_image_name, specs, use_multipart_api, matcher)
			super(global, matcher)
			@source_image_name = source_image_name
			@specs = specs
			@use_multipart_api = use_multipart_api
		end

		def realize(request_state)
			client = @global.thumbnailer or fail 'thumbnailer configuration'

			rendered_specs = {}
			@specs.select do |spec|
				spec.included?(request_state)
			end.each do |spec|
				rendered_specs.merge! spec.render(request_state)
			end

			rendered_specs.empty? and raise NoSpecSelectedError.new(@specs.map(&:image_name))

			source_image = request_state.images[@source_image_name]

			thumbnails = {}
			input_mime_type = nil
			input_width = nil
			input_height = nil

			Thumbnail.stats.incr_total_thumbnail_requests
			Thumbnail.stats.incr_total_thumbnail_requests_bytes source_image.data.bytesize

			if @use_multipart_api
				log.info "thumbnailing '#{@source_image_name}' to multiple specs: #{rendered_specs}"

				# need to reference to local so they are available within thumbnail() block context
				source_image_name = @source_image_name
				logger = log

				begin
					thumbnails = client.with_headers(request_state.headers).thumbnail(source_image.data) do
						rendered_specs.each_pair do |name, spec|
							begin
								thumbnail(*spec)
							rescue HTTPThumbnailerClient::HTTPThumbnailerClientError => error
								logger.warn 'got thumbnailer error while passing specs', error
								raise ThumbnailingError.new(source_image_name, name, error)
							end
						end
					end
				rescue HTTPThumbnailerClient::HTTPThumbnailerClientError => error
					logger.warn 'got thumbnailer error while sending input data', error
					raise ThumbnailingError.new(source_image_name, nil, error)
				end

				input_mime_type = thumbnails.input_mime_type
				input_width = thumbnails.input_width
				input_height = thumbnails.input_height

				# check each thumbnail for errors
				thumbnails = Hash[rendered_specs.keys.zip(thumbnails)]
				thumbnails.each do |name, thumbnail|
					if thumbnail.kind_of? HTTPThumbnailerClient::HTTPThumbnailerClientError
						error = thumbnail
						log.warn 'got single thumbnail error', error
						raise ThumbnailingError.new(@source_image_name, name, error)
					end
				end

				# borrow from memory limit - note that we might have already used too much memory
				thumbnails.each do |name, thumbnail|
					request_state.memory_limit.borrow(thumbnail.data.bytesize, "thumbnail '#{name}'")
				end
			else
				name, rendered_spec = *rendered_specs.first
				log.info "thumbnailing '#{@source_image_name}' to '#{name}' with spec: #{rendered_spec}"

				begin
					thumbnail = client.with_headers(request_state.headers).thumbnail(source_image.data, *rendered_spec)
					request_state.memory_limit.borrow(thumbnail.data.bytesize, "thumbnail '#{name}'")

					input_mime_type = thumbnail.input_mime_type
					input_width = thumbnail.input_width
					input_height = thumbnail.input_height

					thumbnails[name] = thumbnail
				rescue HTTPThumbnailerClient::HTTPThumbnailerClientError => error
					log.warn 'got thumbnailer error', error
					raise ThumbnailingError.new(@source_image_name, name, error)
				end
			end

			# copy input source path and url
			thumbnails.each do |name, thumbnail|
				thumbnail.extend ImageMetaData
				thumbnail.source_path = source_image.source_path
				thumbnail.source_url = source_image.source_url

				Thumbnail.stats.incr_total_thumbnail_thumbnails
				Thumbnail.stats.incr_total_thumbnail_thumbnails_bytes thumbnail.data.bytesize
			end

			# use httpthumbnailer provided information on input image mime type and size
			source_image.mime_type = input_mime_type if input_mime_type
			source_image.width = input_width if input_width
			source_image.height = input_height if input_height

			request_state.images.merge! thumbnails
		end
	end
	Handler::register_node_parser Thumbnail
	StatsReporter << Thumbnail.stats
end

