require 'httpimagestore/ruby_string_template'
require 'digest/sha2'

module Configuration
	class PathNotDefinedError < ConfigurationError
		def initialize(path_name)
			super "path '#{path_name}' not defined"
		end
	end

	class PathRenderingError < ConfigurationError
		def initialize(path_name, template, message)
			super "cannot generate path '#{path_name}' from template '#{template}': #{message}"
		end
	end

	class NoValueForPathTemplatePlaceholerError < PathRenderingError
		def initialize(path_name, template, placeholder)
			super path_name, template, "no value for '\#{#{placeholder}}'"
		end
	end

	class Path < RubyStringTemplate
		def self.match(node)
			node.name == 'path'
		end

		def self.pre(configuration)
			configuration.paths ||= Hash.new{|hash, path_name| raise PathNotDefinedError.new(path_name)}
		end

		def self.parse(configuration, node)
			nodes = []
			nodes << node unless node.values.empty?
			nodes |= node.children

			nodes.empty? and raise NoValueError.new(node, 'path name')
			nodes.each do |node|
				path_name, template = *node.grab_values('path name', 'path template')
				configuration.paths[path_name] = Path.new(path_name, template)
			end
		end

		def initialize(path_name, template)
			super(template) do |locals, name|
				begin
					locals[name]
				rescue ConfigurationError => error
					raise PathRenderingError.new(path_name, template, error.message)
				end or raise NoValueForPathTemplatePlaceholerError.new(path_name, template, name)
			end
		end
	end
	Global.register_node_parser Path
end

