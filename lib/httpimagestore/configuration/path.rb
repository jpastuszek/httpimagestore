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
		def initialize(path_name, template, value_name)
			super path_name, template, "no value for '\#{#{value_name}}'"
		end
	end

	class NoMetaValueForPathTemplatePlaceholerError < PathRenderingError
		def initialize(path_name, template, value_name, meta_value)
			super path_name, template, "need '#{value_name}' to generate value for '\#{#{meta_value}}'"
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
				case name
				when :basename
					path = locals[:path] or raise NoMetaValueForPathTemplatePlaceholerError.new(path_name, template, :path, name)
					path = Pathname.new(path)
					path.basename(path.extname).to_s
				when :dirname
					path = locals[:path] or raise NoMetaValueForPathTemplatePlaceholerError.new(path_name, template, :path, name)
					Pathname.new(path).dirname.to_s
				when :extension
					path = locals[:path] or raise NoMetaValueForPathTemplatePlaceholerError.new(path_name, template, :path, name)
					Pathname.new(path).extname.delete('.')
				when :digest
					return locals[:_digest] if locals.include? :_digest
					data = locals[:body] or raise NoMetaValueForPathTemplatePlaceholerError.new(path_name, template, :body, name) 
					digest = Digest::SHA2.new.update(data).to_s[0,16]
					# cache digest in request locals
					locals[:_digest] = digest
				else
					locals[name] or raise NoValueForPathTemplatePlaceholerError.new(path_name, template, name)
				end
			end
		end
	end
	Global.register_node_parser Path
end

