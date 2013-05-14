require 'httpimagestore/ruby_string_template'
require 'digest/sha2'

module Configuration
	CouldNotFindPathError = Class.new MissingStatementError

	class Path < RubyStringTemplate
		def self.match(node)
			node.name == 'path'
		end

		def self.pre(configuration)
			configuration.paths ||= Hash.new{|hash, path_name| raise CouldNotFindPathError, "could not find '#{path_name}' path"}
		end

		def self.parse(configuration, node)
			node.children.each do |child|
				name, template = *child.values
				template or fail MissingTemplateValueError, "no template for path expression '#{name}' given"
				configuration.paths[name] = Path.new(template)
			end
		end

		def initialize(template)
			super(template) do |locals, name|
				case name
				when :basename
					path = locals[:path] or fail MissingTemplateValueError, 'no path to generate basename from'
					path = Pathname.new(path)
					path.basename(path.extname).to_s
				when :dirname
					path = locals[:path] or fail MissingTemplateValueError, 'no path to generate dirname from'
					Pathname.new(path).dirname.to_s
				when :extension
					path = locals[:path] or fail MissingTemplateValueError, 'no path to generate extension from'
					Pathname.new(path).extname.delete('.')
				when :digest
					return @digest if @digest
					data = locals[:image_data] or fail MissingTemplateValueError, 'no image data to generate digest from'
					@digest = Digest::SHA2.new.update(data).to_s[0,16]
				else
					locals[name]
				end
			end
		end
	end
	Global.register_node_parser Path
end

