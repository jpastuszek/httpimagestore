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

	class BadValueError < SyntaxError
		def initialize(node, value, valid)
			super node, "expected #{value} to be #{valid}"
		end
	end

	class StatementCollisionError < SyntaxError
		def initialize(node, type)
			super node, "only one #{type} type statement can be specified within context"
		end
	end

	# runtime errors
	ConfigurationError = Class.new ArgumentError

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

