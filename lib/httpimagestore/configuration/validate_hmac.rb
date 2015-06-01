require 'httpimagestore/configuration/handler/statement'

module Configuration
	class ValidateHMAC < HandlerStatement
		include ConditionalInclusion

		class NoSecretKeySpecifiedError < ConfigurationError
			def initialize
				super 'no secret key given for validate_hmac (like secret="0f0f0...")'
			end
		end

		class HMACAuthenticationFailedError < ArgumentError
			def initialize(expected_hmac, uri, digest)
				super "HMAC URI authentication with digest '#{digest}' failed: provided HMAC '#{expected_hmac}' for URI '#{uri}' is not valid"
			end
		end

		extend Stats
		def_stats(
			:total_hmac_validations,
			:total_valid_hmac,
			:total_invalid_hmac
		)

		def self.match(node)
			node.name == 'validate_hmac'
		end

		def self.parse(configuration, node)
			expected_hmac = node.grab_values('hmac').first
			secret, digest, remaining = *node.grab_attributes_with_remaining('secret', 'digest')
			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(remaining)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			secret or raise NoSecretKeySpecifiedError

			obj = self.new(expected_hmac.to_template, secret, digest)
			obj.with_conditions(conditions)

			configuration.validators << obj
		end

		def initialize(expected_hmac, secret, digest)
			@expected_hmac = expected_hmac
			@secret = secret
			@digest = digest || 'sha1'
		end

		def realize(request_state)
			expected_hmac = @expected_hmac.render(request_state)

			ValidateHMAC.stats.incr_total_hmac_validations

			uri = request_state[:request_uri]
			digest = OpenSSL::Digest::Digest.new(@digest)

			log.debug "validating URI '#{uri}' HMAC with digest '#{@digest}': expected HMAC '#{expected_hmac}'"
			actual_hmac = OpenSSL::HMAC.hexdigest(digest, @secret, uri)

			if actual_hmac != expected_hmac
				log.warn "invalid HMAC with digest '#{@digest}' for URI '#{uri}'; expected HMAC '#{expected_hmac}'"
				ValidateHMAC.stats.incr_total_invalid_hmac
				raise HMACAuthenticationFailedError.new(expected_hmac, uri, @digest)
			else
				ValidateHMAC.stats.incr_total_valid_hmac
			end
		end
	end
	Handler::register_node_parser ValidateHMAC
	StatsReporter << ValidateHMAC.stats
end

