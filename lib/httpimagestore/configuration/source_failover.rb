require 'httpimagestore/configuration/handler'

module Configuration
	class SourceFailoverAllFailedError < ConfigurationError
		attr_reader :sources, :errors

		def initialize(sources, errors)
			@sources = sources
			@errors = errors
			super "all sources failed: #{sources.zip(errors).map{|s, e| "#{s}(#{e.class.name}: #{e.message})"}.join(', ')}"
		end
	end

	class SourceFailover < Scope
		include ClassLogging

		def self.match(node)
			node.name == 'source_failover'
		end

		def self.parse(configuration, node)
			# support only sources
			handler_configuration = Struct.new(
				:global,
				:sources
			).new
			handler_configuration.global = configuration.global
			handler_configuration.sources = []

			failover = self.new(handler_configuration)
			configuration.sources << failover
			failover.parse(node)
		end

		def realize(request_state)
			errors = []
			@configuration.sources.each do |source|
				begin
					log.debug "trying source: #{source}"
					return source.realize(request_state) unless source.respond_to? :excluded? and source.excluded?(request_state)
				rescue => error
					errors << error
					log.warn "source #{source} failed; trying next source", error
				end
			end
			log.error "all sources: #{@configuration.sources.map(&:to_s).join(', ')} failed; giving up"
			raise SourceFailoverAllFailedError.new(@configuration.sources.to_a, errors)
		end
	end
	Handler::register_node_parser SourceFailover
end
