class RubyStringTemplate < String
	class NoValueForTemplatePlaceholderError < ArgumentError
		def initialize(name, template)
			super "no value for '\#{#{name}}' in template '#{template}'"
		end
	end

	def initialize(template, &resolver)
		super(template.to_s)
		@resolvers = []
		@resolvers << resolver if resolver
		@resolvers << ->(locals, name){locals[name]}
	end

	def initialize_copy(source)
		super
		# copy resolvers array
		resolvers =
		source.instance_eval do
			resolvers = @resolvers
		end
		@resolvers = resolvers.dup
	end

	def render(locals = {})
		self.gsub(/#\{[^\}]+\}/um) do |placeholder|
			name = placeholder.match(/#\{([^\}]*)\}/u).captures.first.to_sym

			@resolvers.find do |resolver|
				value = resolver.call(locals, name)
				value and break value.to_s
			end or fail NoValueForTemplatePlaceholderError.new(name, self)
		end.to_s
	end

	def to_template
		self
	end

	def add_missing_resolver(&resolver)
		@resolvers << resolver
	end

	def with_missing_resolver(&resolver)
		new_template = self.dup
		new_template.add_missing_resolver(&resolver)
		new_template
	end

	def inspect
		"T<#{to_s}>"
	end
end

class String
	def to_template
		RubyStringTemplate.new(self)
	end
end
