require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/path'

describe Configuration do
	describe 'path rendering' do
		it 'should load path and render spec templates' do
			subject = Configuration.read(<<-'EOF')
			path {
				"uri"								"#{path}"
				"hash"							"#{digest}.#{extension}"
				"hash-name"					"#{digest}/#{imagename}.#{extension}"
				"structured"				"#{dirname}/#{digest}/#{basename}.#{extension}"
				"structured-name"		"#{dirname}/#{digest}/#{basename}-#{imagename}.#{extension}"
			}
			EOF

			subject.paths['uri'].render(path: 'test/abc.jpg').should == 'test/abc.jpg'
			subject.paths['hash'].render(path: 'test/abc.jpg', image_data: 'hello').should == '2cf24dba5fb0a30e.jpg'
			subject.paths['hash-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == '2cf24dba5fb0a30e/xbrna.jpg'
			subject.paths['structured'].render(path: 'test/abc.jpg', image_data: 'hello').should == 'test/2cf24dba5fb0a30e/abc.jpg'
			subject.paths['structured-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == 'test/2cf24dba5fb0a30e/abc-xbrna.jpg'
		end

		describe 'error handling' do
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

			it 'should raise NoValueForPathTemplatePlaceholerError if path value is not found' do
				subject = Configuration.read(<<-'EOF')
				path {
					"test"								"#{dirname}#{basename}"
				}
				EOF

				expect {
					subject.paths['test'].render
				}.to raise_error Configuration::NoMetaValueForPathTemplatePlaceholerError, %q{cannot generate path 'test' from template '#{dirname}#{basename}': need 'path' to generate value for '#{dirname}'}
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if image_data value is not found' do
				subject = Configuration.read(<<-'EOF')
				path {
					"test"								"#{digest}"
				}
				EOF

				expect {
					subject.paths['test'].render(path: '')
				}.to raise_error Configuration::NoMetaValueForPathTemplatePlaceholerError, %q{cannot generate path 'test' from template '#{digest}': need 'image_data' to generate value for '#{digest}'}
			end
		end
	end
end

