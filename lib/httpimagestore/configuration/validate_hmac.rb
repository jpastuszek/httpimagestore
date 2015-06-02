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

	class HMACMissingHeaderError < HMACAuthenticationFailedError
		def initialize(digest, header_name)
			super digest, "header '#{header_name}' not found in request body for HMAC verificaton"
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

		def self.new_with_common_options(configuration, node, hmac_qs_param_name, uri_source)
			secret, digest, exclude, remove, remaining = *node.grab_attributes_with_remaining('secret', 'digest', 'exclude', 'remove')
			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(remaining)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			obj = ValidateHMAC.new(hmac_qs_param_name, secret, digest, exclude, remove, uri_source)
			obj.with_conditions(conditions)
			obj
		end

		def initialize(hmac_qs_param_name, secret, digest, exclude, remove, uri_source)
			@hmac_qs_param_name = hmac_qs_param_name
			@secret = secret or raise NoSecretKeySpecifiedError
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

			@uri_source = uri_source

			# check if digest is valid
			begin
				OpenSSL::Digest.digest(@digest, 'blah')
			rescue
				raise UnsupportedDigestError.new(@digest)
			end
		end

		attr_reader :digest

		def realize(request_state)
			expected_hmac = request_state.query_string[@hmac_qs_param_name] or raise HMACMissingError.new(@hmac_qs_param_name, @digest)

			ValidateHMAC.stats.incr_total_hmac_validations

			# we need to remove related query string params so we don't pass them as thumbnailer options
			@remove.each do |rm|
				log.debug "removing query string parameter '#{rm}' used for URI authentication"
				request_state.query_string.delete(rm)
			end

			uri = @uri_source.call(self, request_state) or fail "nil URI"
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

	class ValidateURIHMAC < ValidateHMAC
		def self.match(node)
			node.name == 'validate_uri_hmac'
		end

		def self.parse(configuration, node)
			hmac_qs_param_name = node.grab_values('hmac').first
			obj = self.new_with_common_options(configuration, node, hmac_qs_param_name, ->(obj, request_state){
				request_state.request_uri
			})
			configuration.validators << obj
		end
	end

	class ValidateHeaderHMAC < ValidateHMAC
		def self.match(node)
			node.name == 'validate_header_hmac'
		end

		def self.parse(configuration, node)
			header_name, hmac_qs_param_name = *node.grab_values('header name', 'hmac')
			header_name = header_name.upcase.gsub('_', '-')
			obj = self.new_with_common_options(configuration, node, hmac_qs_param_name, ->(obj, request_state){
				request_state.request_headers[header_name] or raise HMACMissingHeaderError.new(obj.digest, header_name)
			})
			configuration.validators << obj
		end
	end

	Handler::register_node_parser ValidateURIHMAC
	Handler::register_node_parser ValidateHeaderHMAC
	StatsReporter << ValidateHMAC.stats
end

