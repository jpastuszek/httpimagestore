require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = RootLogger.new('/dev/null')
#Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/validate_hmac'

describe Configuration do
	describe 'validate_hmac' do
		subject do
			Configuration.read(<<-'EOF')
			get {
				validate_hmac "#{hmac}" secret="key" digest="sha1"
			}
			EOF
		end

		context 'given example secret and hash for SHA1' do
			let :state do
				state = Configuration::RequestState.new(
					'', {
						hmac: 'de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9'
					}
				)
				#state[:request_uri] = '/hello/world?hmac="dfafds"' # REQUEST_URI
				state[:request_uri] = 'The quick brown fox jumps over the lazy dog' # REQUEST_URI
				state
			end

			it 'should pass validation' do
				subject.handlers.should have(1).handler
				subject.handlers[0].validators.should_not be_nil
				subject.handlers[0].validators.should have(1).validator
				expect {
					subject.handlers[0].validators[0].realize(state)
				}.to_not raise_error
			end

			context 'with default digest' do
				subject do
					Configuration.read(<<-'EOF')
					get {
						validate_hmac "#{hmac}" secret="key"
					}
					EOF
				end

				it 'should pass validation' do
					subject.handlers.should have(1).handler
					subject.handlers[0].validators.should_not be_nil
					subject.handlers[0].validators.should have(1).validator
					expect {
						subject.handlers[0].validators[0].realize(state)
					}.to_not raise_error
				end
			end

			context 'with no secret' do
				it 'should fail configuration parsing' do
					expect {
						Configuration.read(<<-'EOF')
						get {
							validate_hmac "#{hmac}"
						}
						EOF
					}.to raise_error Configuration::ValidateHMAC::NoSecretKeySpecifiedError
				end
			end
		end

		context 'given invalid HMAC' do
			let :state do
				state = Configuration::RequestState.new(
					'', {
						hmac: 'blah'
					}
				)
				#state[:request_uri] = '/hello/world?hmac="dfafds"' # REQUEST_URI
				state[:request_uri] = 'The quick brown fox jumps over the lazy dog' # REQUEST_URI
				state
			end

			it 'should fail validation' do
				expect {
					subject.handlers[0].validators[0].realize(state)
				}.to raise_error Configuration::ValidateHMAC::HMACAuthenticationFailedError, "HMAC URI authentication with digest 'sha1' failed: provided HMAC 'blah' for URI 'The quick brown fox jumps over the lazy dog' is not valid"
			end
		end
	end
end

