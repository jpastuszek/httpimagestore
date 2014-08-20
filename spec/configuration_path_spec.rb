require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/handler'
require 'httpimagestore/configuration/path'

describe Configuration do
	describe 'path rendering' do
		it 'should load paths form single line and multi line declarations and render spec templates' do
			subject = Configuration.read(<<-'EOF')
			path "uri"						"#{path}"
			path "hash"						"#{input_digest}.#{extension}"
			path {
				"hash-name"					"#{input_digest}/#{image_name}.#{extension}"
				"structured"				"#{dirname}/#{input_digest}/#{basename}.#{extension}"
				"structured-name"		"#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{extension}"
			}
			EOF

			subject.paths['uri'].render(path: 'test/abc.jpg').should == 'test/abc.jpg'
			subject.paths['hash'].render(input_digest: '2cf24dba5fb0a30e', extension: 'jpg').should == '2cf24dba5fb0a30e.jpg'
			subject.paths['hash-name'].render(input_digest: '2cf24dba5fb0a30e', image_name: 'xbrna', extension: 'jpg').should == '2cf24dba5fb0a30e/xbrna.jpg'
			subject.paths['structured'].render(dirname: 'test', input_digest: '2cf24dba5fb0a30e', basename: 'abc', extension: 'jpg').should == 'test/2cf24dba5fb0a30e/abc.jpg'
			subject.paths['structured-name'].render(dirname: 'test', input_digest: '2cf24dba5fb0a30e', basename: 'abc', extension: 'jpg', image_name: 'xbrna').should == 'test/2cf24dba5fb0a30e/abc-xbrna.jpg'
		end

		describe 'error handling' do
			it 'should raise NoValueError on missing path name' do
				expect {
					Configuration.read(<<-'EOF')
						path
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'path': expected path name}
			end

			it 'should raise NoValueError on missing path template' do
				expect {
					Configuration.read(<<-'EOF')
						path {
							"blah"
						}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing '"blah"': expected path template}
			end

			it 'should raise PathNotDefinedError if path lookup fails' do
				subject = Configuration.read('')

				expect {
					subject.paths['blah']
				}.to raise_error Configuration::PathNotDefinedError, "path 'blah' not defined"
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if locals value is not found' do
				subject = Configuration.read(<<-'EOF')
				path {
					"test"								"#{abc}#{xyz}"
				}
				EOF

				expect {
					subject.paths['test'].render
				}.to raise_error Configuration::NoValueForPathTemplatePlaceholerError, %q{cannot generate path 'test' from template '#{abc}#{xyz}': no value for '#{abc}'}
			end
		end

		describe 'rendering from RequestState' do
			let :state do
				Configuration::RequestState.new(
					'test',
					{operation: 'pad'},
					'test/abc.jpg',
					{width: '123', height: '321'}
				)
			end

			subject do
				Configuration.read(<<-'EOF')
				path "uri"						"#{path}"
				path "hash"						"#{input_digest}.#{extension}"
				path {
					"hash-name"					"#{input_digest}/#{image_name}.#{extension}"
					"structured"				"#{dirname}/#{input_digest}/#{basename}.#{extension}"
					"structured-name"		"#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{extension}"
				}
				path "name"						"#{image_name}"
				path "base"						"#{basename}"
				EOF
			end

			it 'should render path using meta variables and locals' do

				subject.paths['uri'].render(state).should == 'test/abc.jpg'
				subject.paths['hash'].render(state).should == '9f86d081884c7d65.jpg'
				subject.paths['hash-name'].render(state.with_locals(image_name: 'xbrna')).should == '9f86d081884c7d65/xbrna.jpg'
				subject.paths['structured'].render(state).should == 'test/9f86d081884c7d65/abc.jpg'
				subject.paths['structured-name'].render(state.with_locals(image_name: 'xbrna')).should == 'test/9f86d081884c7d65/abc-xbrna.jpg'
			end

			describe 'error handling' do
				let :state do
					Configuration::RequestState.new(
						'',
						{operation: 'pad'},
						'test/abc.jpg',
						{width: '123', height: '321'}
					)
				end

				it 'should raise PathRenderingError if body was expected but not provided' do
					expect {
						subject.paths['hash'].render(state)
					}.to raise_error Configuration::PathRenderingError, %q{cannot generate path 'hash' from template '#{input_digest}.#{extension}': need not empty request body to generate value for 'input_digest'}
				end

				it 'should raise PathRenderingError if variable not defined' do
					expect {
						subject.paths['name'].render(state)
					}.to raise_error Configuration::PathRenderingError, %q{cannot generate path 'name' from template '#{image_name}': variable 'image_name' not defined}
				end

				it 'should raise PathRenderingError if meta variable dependent variable not defined' do
					state = Configuration::RequestState.new(
						'',
						{operation: 'pad'},
						nil,
						{width: '123', height: '321'}
					)
					expect {
						subject.paths['base'].render(state)
					}.to raise_error Configuration::PathRenderingError, %q{cannot generate path 'base' from template '#{basename}': need 'path' variable to generate value for 'basename'}
				end
			end
		end
	end
end

