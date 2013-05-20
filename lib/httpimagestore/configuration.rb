require 'sdl4r'
require 'pathname'
require 'ostruct'
require 'unicorn-cuba-base'

module Configuration
	# parsing errors
	class SyntaxError < ArgumentError
		def initialize(node, message)
			super "syntax error while parsing '#{node}': #{message}"
		end
	end

	class NoAttributeError < SyntaxError
		def initialize(node, attribute)
			super node, "expected '#{attribute}' attribute to be set"
		end
	end

	class NoValueError < SyntaxError
		def initialize(node, value)
			super node, "expected #{value}"
		end
	end

	class BadAttributeValueError < SyntaxError
		def initialize(node, attribute, value, valid)
			super node, "expected '#{attribute}' attribute value to be #{valid.map(&:inspect).join(' or ')}; got: #{value.inspect}"
		end
	end

	class UnexpectedValueError < SyntaxError
		def initialize(node, values)
			super node, "unexpected values: #{values.map(&:inspect).join(', ')}"
		end
	end

	class UnexpectedAttributesError < SyntaxError
		def initialize(node, attributes)
			super node, "unexpected attributes: #{attributes.keys.map{|a| "'#{a}'"}.join(', ')}"
		end
	end

	class StatementCollisionError < SyntaxError
		def initialize(node, type)
			super node, "only one #{type} type statement can be specified within context"
		end
	end

	# runtime errors
	ConfigurationError = Class.new ArgumentError

	module SDL4RTagExtensions
		def required_attributes(*list)
			list.each do |attribute|
				attribute(attribute) or raise NoAttributeError.new(self, attribute)
			end
			true
		end

		def grab_attributes(*list)
			attributes = self.attributes.dup
			values = list.map do |attribute|
				value = attributes.delete(attribute)
				value
			end
			attributes.empty? or raise UnexpectedAttributesError.new(self, attributes)
			values
		end

		def grab_attributes_with_remaining(*list)
			attributes = self.attributes.dup
			values = list.map do |attribute|
				value = attributes.delete(attribute)
				value
			end
			values | [attributes]
		end

		def valid_attribute_values(attribute, *valid)
			value = self.attribute(attribute)
			valid.include? value or raise BadAttributeValueError.new(self, attribute, value, valid)
		end

		def grab_values(*list)
			values = self.values.dup
			out = []
			list.each do |name|
				val = values.shift or raise NoValueError.new(self, name)
				out << val
			end
			values.empty? or raise UnexpectedValueError.new(self, values)
			out
		end
	end

	class Scope
		include ClassLogging

		def self.node_parsers
			@node_parsers ||= []
		end

		def self.register_node_parser(parser)
			parser.logger = logger_for(parser) if parser.respond_to? :logger=
			node_parsers << parser
		end

		def initialize(configuration)
			@configuration = configuration
		end

		def parse(node)
			self.class.node_parsers.each do |parser|
				parser.pre(@configuration) if parser.respond_to? :pre
			end

			node.children.each do |node|
				parser = self.class.node_parsers.find do |parser|
					parser.match node
				end
				if parser
					parser.parse(@configuration, node)
				else
					log.warn "unexpected statement: #{node.name}"
				end
			end

			self.class.node_parsers.each do |parser|
				parser.post(@configuration) if parser.respond_to? :post
			end
			@configuration
		end
	end

	class Global < Scope
	end

	def self.from_file(config_file, defaults = {})
		read Pathname.new(config_file), defaults
	end

	def self.read(config, defaults = {})
		parse SDL4R::read(config), defaults
	end

	def self.parse(root, defaults = {})
		configuration = OpenStruct.new
		configuration.defaults = defaults
		Global.new(configuration).parse(root)
	end
end

class SDL4R::Tag
	include Configuration::SDL4RTagExtensions
end

