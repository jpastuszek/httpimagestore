require 'httpthumbnailer-client'
require 'httpimagestore/ruby_string_template'

module Configuration
	class Thumnailer
		def self.match(node)
			node.name == 'thumbnailer'
		end

		def self.pre(configuration)
			configuration.thumbnailer = Struct.new(:url, :client).new
			configuration.thumbnailer.url = configuration.defaults[:thumbnailer_url] || 'http://localhost:3100'
		end

		def self.parse(configuration, node)
			configuration.thumbnailer.url = node.attribute('url') or raise MissingArgumentError, 'thumbnailer url'
		end

		def self.post(configuration)
			configuration.thumbnailer.client = HTTPThumbnailerClient.new(configuration.thumbnailer.url)
		end
	end
	Global.register_node_parser Thumnailer

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
			def initialize(image_name, method, width, height, format, options = {})
				@image_name = image_name
				@method = RubyStringTemplate.new(method)
				@width = RubyStringTemplate.new(width)
				@height = RubyStringTemplate.new(height)
				@format = RubyStringTemplate.new(format)
				@options = options.inject({}){|h, v| h[v.first] = RubyStringTemplate.new(v.last); h}
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
			source_image_name = node.values.first or raise MissingArgumentError, 'source image name'
			specs = node.children.map do |node|
				image_name = node.values.first or raise MissingArgumentError, 'output image name'
				attributes = node.attributes
				ThumbnailSpec.new(
					image_name,
					attributes.delete("operation") || 'fit',
					attributes.delete("width") || 'input',
					attributes.delete("height") || 'input',
					attributes.delete("format") || 'jpeg',
					attributes
				)
			end

			configuration.image_sources << self.new(source_image_name, configuration, specs)
		end

		def initialize(source_image_name, configuration, specs)
			@source_image_name = source_image_name
			@configuration = configuration
			@specs = specs
		end

		def realize(request_state)
			@configuration.global.thumbnailer or raise MissingStatementError, 'thumbnailer configuration'
			client = @configuration.global.thumbnailer.client or raise MissingStatementError, 'thumbnailer client'

			rendered_specs = {}
			@specs.each do |spec|
				rendered_specs.merge! spec.render(request_state.locals)
			end
			log.info "thumbnailing '#{@source_image_name}' to specs: #{rendered_specs}"
			return if rendered_specs.empty?

			image = request_state.images[@source_image_name]

			thumbnails = client.thumbnail(image.data) do
				rendered_specs.values.each do |spec|
					thumbnail(*spec)
				end
			end

			images = Hash[rendered_specs.keys.zip(thumbnails)]
			images.each do |name, thumbnail|
				raise ThumbnailingError.new(@source_image_name, name, thumbnail) if thumbnail.kind_of? HTTPThumbnailerClient::ThumbnailingError
			end

			# update input image mime type from httpthumbnailer provided information
			image.mime_type = thumbnails.input_mime_type unless image.mime_type

			request_state.images.merge! images
		end
	end
	Handler::register_node_parser Thumbnail
end

