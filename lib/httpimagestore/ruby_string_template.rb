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
		template = self.to_s
		values = {}

		# use gsub with block instead!
		template.scan(/#\{[^\}]+\}/um).uniq.each do |placeholder|
			name = placeholder.match(/#\{([^\}]*)\}/u).captures.first.to_sym

			value = nil
			@resolvers.find{|resolver| value = resolver.call(locals, name)} or fail NoValueForTemplatePlaceholderError.new(name, self)
			values[placeholder] = value.to_s
		end

		values.each_pair do |placeholder, value|
			template.gsub!(placeholder, value)
		end

		template
	end

	def to_template
		self
	end

	#def inspect
		#super + "[#{@resolvers}]"
	#end

	def add_missing_resolver(&resolver)
		@resolvers << resolver
	end

	def with_missing_resolver(&resolver)
		new_template = self.dup
		new_template.add_missing_resolver(&resolver)
		new_template
	end
end

class String
	def to_template
		RubyStringTemplate.new(self)
	end
end
