class RubyStringTemplate
	class NoValueForTemplatePlaceholderError < ArgumentError
		def initialize(name, template)
			super "no value for '\#{#{name}}' in template '#{template}'"
		end
	end
	
	def initialize(template, &resolver)
		@template = template.to_s
		@resolver = resolver ? resolver : ->(locals, name){locals[name]}
	end

	def render(locals = {})
		template = @template
		while tag = template.match(/(#\{[^\}]+\})/m)
			tag = tag.captures.first
			name = tag.match(/#\{([^\}]*)\}/).captures.first.to_sym
			value = @resolver.call(locals, name)
			value or fail NoValueForTemplatePlaceholderError.new(name, @template)
			value = value.to_s
			template = template.gsub(tag, value)
		end
		template
	end
end

