require 'sdl4r'
require 'pathname'
require 'ostruct'
require 'unicorn-cuba-base'

module Configuration
	class Scope
		include ClassLogging

		ConfigurationError = Class.new ArgumentError
		MissingStatementError = Class.new ConfigurationError
		MissingArgumentError = Class.new ConfigurationError

		def self.node_parsers
			@node_parsers ||= []
		end

		def self.register_node_parser(parser)
			node_parsers << parser
		end

		def initialize(configuration)
			@configuration = configuration
		end

		def parse(node)
			self.class.node_parsers.each do |parser|
				parser.pre_default(@configuration) if parser.respond_to? :pre_default
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
				parser.post_default(@configuration) if parser.respond_to? :post_default
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

