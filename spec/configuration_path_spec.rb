require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/path'

describe Configuration do
	subject do
		Configuration.from_file(support_dir + 'path.cfg')
	end

	describe 'path rendering' do
		it 'should load path and render spec templates' do
			subject.paths['uri'].render(path: 'test/abc.jpg').should == 'test/abc.jpg'
			subject.paths['hash'].render(path: 'test/abc.jpg', image_data: 'hello').should == '2cf24dba5fb0a30e.jpg'
			subject.paths['hash-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == '2cf24dba5fb0a30e/xbrna.jpg'
			subject.paths['structured'].render(path: 'test/abc.jpg', image_data: 'hello').should == 'test/2cf24dba5fb0a30e/abc.jpg'
			subject.paths['structured-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == 'test/2cf24dba5fb0a30e/abc-xbrna.jpg'
		end

		describe 'error handling' do
			it 'should raise NoValueError on missing path template' do
				expect {
					Configuration.read(<<-EOF)
						path {
							"blah"
						}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing '"blah"': expected path template}
			end

			it 'should raise PathNotDefinedError if path lookup fails' do
				expect {
					subject.paths['blah']
				}.to raise_error Configuration::PathNotDefinedError, "path 'blah' not defined"
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if locals value is not found' do
				expect {
					subject.paths['uri'].render
				}.to raise_error Configuration::NoValueForPathTemplatePlaceholerError, %q{cannot generate path 'uri' from template '#{path}': no value for '#{path}'} 
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if path value is not found' do
				expect {
					subject.paths['structured'].render
				}.to raise_error Configuration::NoMetaValueForPathTemplatePlaceholerError, %q{cannot generate path 'structured' from template '#{dirname}/#{digest}/#{basename}.#{extension}': need 'path' to generate value for '#{dirname}'}
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if image_data value is not found' do
				expect {
					subject.paths['structured'].render(path: '')
				}.to raise_error Configuration::NoMetaValueForPathTemplatePlaceholerError, %q{cannot generate path 'structured' from template '#{dirname}/#{digest}/#{basename}.#{extension}': need 'image_data' to generate value for '#{digest}'}
			end
		end
	end
end

