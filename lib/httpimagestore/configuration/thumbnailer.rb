require 'httpimagestore/ruby_string_template'
require 'httpimagestore/thumbnail_class'

module Configuration
	class Thumnailer < Struct.new(:url)
		def self.match(node)
			node.name == 'thumbnailer'
		end

		def self.pre_default(configuration)
			configuration.thumbnailer = self.new(configuration.defaults[:thumbnailer_url] || 'http://localhost:3100')
		end

		def self.parse(configuration, node)
			url = node.attribute('url') or raise MissingArgumentError, 'thumbnailer url'
			configuration.thumbnailer = self.new(url)
		end
	end
	Global.register_node_parser Thumnailer

	class Thumbnail
		class ThumbnailSpec
			def initialize(image_name, method, width, height, format, options)
				@image_name = image_name
				@method = RubyStringTemplate.new(method)
				@width = RubyStringTemplate.new(width)
				@height = RubyStringTemplate.new(height)
				@format = RubyStringTemplate.new(format)
				@options = options.map do |k, v|
					next k, RubyStringTemplate.new(format)
				end
			end

			attr_reader :image_name

			def render(locals = {})
				[
					@method.render(locals),
					@width.render(locals),
					@height.render(locals),
					@format.render(locals),
					@options.map do |k, v| 
						next k, v.render(locals)
					end
				]
			end
		end

		def self.match(node)
			node.name == 'thumbnail'
		end

		def self.parse(configuration, node)
			name = node.values.first or raise MissingArgumentError, 'image name'
			specs = node.children.map do |node|
				image_name = node.values.first or raise MissingArgumentError, 'image name'
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
			
			configuration.image_source << Thumbnail.new(specs)
		end

		def initialize(specs)
			@specs = specs
		end

		def render(locals = {})
			@specs.map do |spec|
				p spec
				spec.render(locals)
			end
		end
	end
	Handler::register_node_parser Thumbnail
end

