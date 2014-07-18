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
		template = @template.dup
		values = {}

		template.scan(/#\{[^\}]+\}/um).uniq.each do |placeholder|
			name = placeholder.match(/#\{([^\}]*)\}/u).captures.first.to_sym
			value = @resolver.call(locals, name)
			value or fail NoValueForTemplatePlaceholderError.new(name, @template)
			values[placeholder] = value.to_s
		end

		values.each_pair do |placeholder, value|
			template.gsub!(placeholder, value)
		end

		template
	end
end

