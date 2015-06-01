require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = RootLogger.new('/dev/null')
Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/validate_hmac'

describe Configuration do
	describe 'validate_hmac' do
		context 'given example secret and hash for SHA1' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key" digest="sha1"
				}
				EOF
			end

			let :state do
				request_state do |rs|
					rs.matches hmac: 'de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9'
					rs.request_uri 'The quick brown fox jumps over the lazy dog'
				end
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
		end

		context 'given example secret and hash for SHA256' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key" digest="sha256"
				}
				EOF
			end

			let :state do
				request_state do |rs|
					rs.matches hmac: 'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8'
					rs.request_uri 'The quick brown fox jumps over the lazy dog'
				end
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

		context 'given example secret and hash for MD5' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key" digest="md5"
				}
				EOF
			end

			let :state do
				request_state do |rs|
					rs.matches hmac: '80070713463e7749b90c2dc24911e275'
					rs.request_uri 'The quick brown fox jumps over the lazy dog'
				end
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

		context 'given invalid HMAC' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key"
				}
				EOF
			end

			let :state do
				request_state do |rs|
					rs.matches hmac: 'blah'
					rs.request_uri 'The quick brown fox jumps over the lazy dog'
				end
			end

			it 'should fail validation' do
				expect {
					subject.handlers[0].validators[0].realize(state)
				}.to raise_error Configuration::HMACAuthenticationFailedError, "HMAC URI authentication with digest 'sha1' failed: provided HMAC 'blah' for URI 'The quick brown fox jumps over the lazy dog' is not valid"
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
				}.to raise_error Configuration::NoSecretKeySpecifiedError
			end
		end

		context 'with unsupported digest' do
			it 'should fail configuration parsing' do
				expect {
					Configuration.read(<<-'EOF')
					get {
						validate_hmac "#{hmac}" secret="key" digest="blah"
					}
					EOF
				}.to raise_error Configuration::UnsupportedDigestError, "digest 'blah' is not supported"
			end
		end

		context 'when excluding HMAC query string parameter' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key" exclude="hmac"
				}
				EOF
			end

			context 'with URI containing only HMAC query string parameter ' do
				let :state do
					request_state do |rs|
						rs.matches hmac: '6917ed5233daf7fbbbb5827687c023a790cfc1f5'
						rs.request_uri '/hello/world?hmac=6917ed5233daf7fbbbb5827687c023a790cfc1f5'
					end
				end

				it 'should validate against URI without query string' do
					expect {
						subject.handlers[0].validators[0].realize(state)
					}.to_not raise_error
				end

				context 'with URI containing also other query string parameters' do
					let :state do
						request_state do |rs|
							rs.matches hmac: '10f99ef4d2a176447a49c4a85a52423ae8e108b9'
							rs.request_uri '/hello/world?abc=xyz&hmac=10f99ef4d2a176447a49c4a85a52423ae8e108b9&zzz=abc'
						end
					end

					it 'should validate against URI with removed query string parameter' do
						expect {
							subject.handlers[0].validators[0].realize(state)
						}.to_not raise_error
					end
				end
			end
		end

		context 'when excluding HMAC and some other query string parameters' do
			subject do
				Configuration.read(<<-'EOF')
				get {
					validate_hmac "#{hmac}" secret="key" exclude="hmac,foo"
				}
				EOF
			end

			context 'with URI containing also other query string parameters' do
				let :state do
					request_state do |rs|
						rs.matches hmac: '10f99ef4d2a176447a49c4a85a52423ae8e108b9'
						rs.request_uri '/hello/world?abc=xyz&foo=bar&hmac=10f99ef4d2a176447a49c4a85a52423ae8e108b9&zzz=abc'
					end
				end

				it 'should validate against URI with removed query string parameter' do
					expect {
						subject.handlers[0].validators[0].realize(state)
					}.to_not raise_error
				end
			end

			context 'with URI containing also other query string parameters (last)' do
				let :state do
					request_state do |rs|
						rs.matches hmac: '10f99ef4d2a176447a49c4a85a52423ae8e108b9'
						rs.request_uri '/hello/world?abc=xyz&foo=bar&zzz=abc&hmac=10f99ef4d2a176447a49c4a85a52423ae8e108b9'
					end
				end

				it 'should validate against URI with removed query string parameter' do
					expect {
						subject.handlers[0].validators[0].realize(state)
					}.to_not raise_error
				end
			end
		end

		describe 'conditional inclusion support' do
			let :state do
				request_state do |rs|
					rs.matches(
						hmac: 'blah',
						hello: 'world',
						xyz: 'true'
					)
					rs.request_uri 'The quick brown fox jumps over the lazy dog'
				end
			end

			describe 'if-variable-matches' do
				subject do
					Configuration.read(<<-'EOF')
					get {
						validate_hmac "#{hmac}" secret="key" if-variable-matches="hello:world"
						validate_hmac "#{hmac}" secret="key" if-variable-matches="hello:blah"
						validate_hmac "#{hmac}" secret="key" if-variable-matches="xyz"
					}
					EOF
				end
				it 'should perform validation if variable value matches or when no value is expected is not empty' do
					subject.handlers[0].validators[0].excluded?(state).should be_false
					subject.handlers[0].validators[1].excluded?(state).should be_true
					subject.handlers[0].validators[2].excluded?(state).should be_false
				end
			end
		end
	end
end

