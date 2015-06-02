require 'httpimagestore/configuration/handler/statement'

module Configuration
	class NoSecretKeySpecifiedError < ConfigurationError
		def initialize
			super 'no secret key given for validate_hmac (like secret="0f0f0...")'
		end
	end

	class UnsupportedDigestError < ConfigurationError
		def initialize(digest)
			super "digest '#{digest}' is not supported"
		end
	end

	class HMACAuthenticationFailedError < ArgumentError
		def initialize(digest, msg)
			super "HMAC URI authentication with digest '#{digest}' failed: #{msg}"
		end
	end

	class HMACMismatchError < HMACAuthenticationFailedError
		def initialize(expected_hmac, uri, digest)
			super digest, "provided HMAC '#{expected_hmac}' for URI '#{uri}' is not valid"
		end
	end

	class HMACMissingError < HMACAuthenticationFailedError
		def initialize(hmac_qs_param_name, digest)
			super digest, "HMAC query string parameter '#{hmac_qs_param_name}' not found"
		end
	end

	class ValidateHMAC < HandlerStatement
		include ConditionalInclusion

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
			hmac_qs_param_name = node.grab_values('hmac').first
			secret, digest, exclude, remove, remaining = *node.grab_attributes_with_remaining('secret', 'digest', 'exclude', 'remove')
			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(remaining)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			secret or raise NoSecretKeySpecifiedError

			obj = self.new(hmac_qs_param_name.to_template, secret, digest, exclude, remove)
			obj.with_conditions(conditions)

			configuration.validators << obj
		end

		def initialize(hmac_qs_param_name, secret, digest, exclude, remove)
			@hmac_qs_param_name = hmac_qs_param_name
			@secret = secret
			@digest = digest || 'sha1'

			@exclude = (exclude || '').split(/ *, */)
			# always exclude hmac from hash computation
			@exclude << @hmac_qs_param_name

			# by default remove hmac for qs params but can be kept if remove=""
			@remove = if remove
				remove.split(/ *, */)
			else
				[@hmac_qs_param_name]
			end

			# check if digest is valid
			begin
				OpenSSL::Digest.digest(@digest, 'blah')
			rescue
				raise UnsupportedDigestError.new(@digest)
			end
		end

		def realize(request_state)
			expected_hmac = request_state[:query_string][@hmac_qs_param_name] or raise HMACMissingError.new(@hmac_qs_param_name, @digest)

			ValidateHMAC.stats.incr_total_hmac_validations

			# we need to remove related query string params so we don't pass them as thumbnailer options
			@remove.each do |rm|
				log.debug "removing query string parameter '#{rm}' used for URI authentication"
				request_state[:query_string].delete(rm)
			end

			uri = request_state[:request_uri]
			uri = @exclude.inject(uri) do |uri, ex|
				uri.gsub(/(\?|&)#{ex}=.*?($|&)/, '\1')
			end
			uri.sub!(/(\?|&)$/, '')

			digest = OpenSSL::Digest::Digest.new(@digest)

			log.debug "validating URI '#{uri}' HMAC with digest '#{@digest}': expected HMAC '#{expected_hmac}'"
			actual_hmac = OpenSSL::HMAC.hexdigest(digest, @secret, uri)

			if actual_hmac != expected_hmac
				log.warn "invalid HMAC with digest '#{@digest}' for URI '#{uri}'; expected HMAC '#{expected_hmac}'"
				ValidateHMAC.stats.incr_total_invalid_hmac
				raise HMACMismatchError.new(expected_hmac, uri, @digest)
			else
				ValidateHMAC.stats.incr_total_valid_hmac
			end
		end
	end
	Handler::register_node_parser ValidateHMAC
	StatsReporter << ValidateHMAC.stats
end

