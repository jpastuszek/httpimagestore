class RubyStringTemplate
	MissingTemplateValueError = Class.new ArgumentError
	
	def initialize(template, &resolver)
		@template = template
		@resolver = resolver ? resolver : ->(locals, name){locals[name]}
	end

	def render(locals = {})
		template = @template.to_s
		while tag = template.match(/(#\{[^\}]+\})/m)
			tag = tag.captures.first
			name = tag.match(/#\{([^\}]*)\}/).captures.first.to_sym
			value = @resolver.call(locals, name)
			value or fail MissingTemplateValueError, "no value for '#{name}' in template '#{template}'"
			value = value.to_s
			template = template.gsub(tag, value)
		end
		template
	end
end

