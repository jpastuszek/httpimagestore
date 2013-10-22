require_relative 'spec_helper'
require_relative 'support/cuba_response_env'

require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/handler'
require 'httpimagestore/configuration/output'
MemoryLimit.logger = Logger.new('/dev/null')

describe Configuration do
	describe Configuration::Handler do
		subject do
			Configuration.read(<<-EOF)
			get "thumbnail" "v1" ":operation" ":width" ":height" ":options" {
			}

			put "thumbnail" "v1" ":test/.+/" {
			}

			post {
			}
			EOF
		end

		describe 'http method and matchers' do
			it 'should provide request http_method and uri_matchers' do
				subject.handlers.length.should == 3

				subject.handlers[0].http_method.should == 'get'
				subject.handlers[0].uri_matchers.map{|m| m.names}.flatten.should == [:operation, :width, :height, :options]

				subject.handlers[1].http_method.should == 'put'
				subject.handlers[1].uri_matchers.map{|m| m.names}.flatten.should == [:test]

				subject.handlers[2].http_method.should == 'post'
				subject.handlers[2].uri_matchers.should be_empty
			end
		end

		describe Configuration::RequestState do
			subject do
				Configuration::RequestState.new(
					'test',
					{operation: 'pad'},
					'/hello/world.jpg',
					{width: '123', height: '321'}
				)
			end

			it 'should behave like hash' do
				subject['a'] = 'b'
				subject['a'].should == 'b'
			end

			it 'should provide body' do
				subject.body.should == 'test'
			end

			describe 'variables' do
				it 'should provide path' do
					subject[:path].should == '/hello/world.jpg'
				end

				it 'should provide matches' do
					subject[:operation].should == 'pad'
				end

				it 'should provide query_string_options' do
					subject[:query_string_options].should == 'height:321,width:123'
				end

				it 'should provide request body digest' do
					subject[:digest].should == '9f86d081884c7d65' # deprecated
					subject[:input_digest].should == '9f86d081884c7d65'
				end

				it 'should provide request body full sha256 checsum' do
					subject[:input_sha256].should == '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'
				end

				it 'should provide input image mime extension' do
					subject.images['input'] = Struct.new(:data, :mime_type).new('image body', 'image/jpeg')
					subject.images['input'].extend Configuration::ImageMetaData
					subject[:input_image_mime_extension].should == 'jpg'
				end

				it 'should provide input image width and height' do
					subject.images['input'] = Struct.new(:data, :width, :height).new('image body', 128, 256)
					subject[:input_image_width].should == 128
					subject[:input_image_height].should == 256
				end

				it 'should provide image body digest' do
					subject.images['abc'] = Struct.new(:data).new('image body')
					subject.with_locals(image_name: 'abc')[:image_digest].should == 'f5288dd892bb007b'
				end

				it 'should provide image body full sha256 checsum' do
					subject.images['abc'] = Struct.new(:data).new('image body')
					subject.with_locals(image_name: 'abc')[:image_sha256].should == 'f5288dd892bb007b607304a8fb20c91ea769dcd04d82cc8ddf3239602867eb4d'
				end

				it 'should provide uuid' do
					subject[:uuid].should_not be_empty
					subject[:uuid].should == subject[:uuid]
				end

				it 'should provide extension' do
					subject[:extension].should == 'jpg'
				end

				it 'should provide dirname' do
					subject[:dirname].should == '/hello'
				end

				it 'should provide basename' do
					subject[:basename].should == 'world'
				end

				it 'should provide image mime extension' do
					subject.images['abc'] = Struct.new(:data, :mime_type).new('image body', 'image/jpeg')
					subject.images['abc'].extend Configuration::ImageMetaData
					subject.with_locals(image_name: 'abc')[:mimeextension].should == 'jpg' # deprecated
					subject.with_locals(image_name: 'abc')[:image_mime_extension].should == 'jpg'
				end

				it 'should provide image width and height' do
					subject.images['abc'] = Struct.new(:data, :width, :height).new('image body', 128, 256)
					subject.with_locals(image_name: 'abc')[:image_width].should == 128
					subject.with_locals(image_name: 'abc')[:image_height].should == 256
				end

				describe "error handling" do
					it 'should raise NoRequestBodyToGenerateMetaVariableError when empty body was provided and body needed for variable calculation' do
						subject = Configuration::RequestState.new(
							'',
							{operation: 'pad'},
							'/hello/world.jpg',
							{width: '123', height: '321'}
						)

						expect {
							subject[:input_digest]
						}.to raise_error Configuration::NoRequestBodyToGenerateMetaVariableError, %q{need not empty request body to generate value for 'input_digest'}
					end

					it 'should raise ImageNotLoadedError when asking for image related variable of not loaded image' do
						expect {
							subject.with_locals(image_name: 'abc')[:image_mime_extension]
						}.to raise_error Configuration::ImageNotLoadedError, %q{image 'abc' not loaded}
					end

					it 'should raise NoVariableToGenerateMetaVariableError when no image_name was defined' do
						expect {
							subject.with_locals({})[:image_mime_extension]
						}.to raise_error Configuration::NoVariableToGenerateMetaVariableError, %q{need 'image_name' variable to generate value for 'image_mime_extension'}
					end

					it 'should raise NoVariableToGenerateMetaVariableError when no path was defined' do
						expect {
							subject.delete(:path)
							subject[:basename]
						}.to raise_error Configuration::NoVariableToGenerateMetaVariableError, %q{need 'path' variable to generate value for 'basename'}
					end

					it 'should raise NoImageDataForVariableError when image has no mime type' do
						subject.images['abc'] = Struct.new(:data, :mime_type).new('image body', nil)
						subject.images['abc'].extend Configuration::ImageMetaData
						expect {
							subject.with_locals(image_name: 'abc')[:image_mime_extension]
						}.to raise_error Configuration::NoImageDataForVariableError, %q{image 'abc' does not have data for variable 'image_mime_extension'}
					end

					it 'should raise NoImageDataForVariableError when image has no known width or height' do
						subject.images['abc'] = Struct.new(:data, :width, :height).new('image body', nil, nil)
						expect {
							subject.with_locals(image_name: 'abc')[:image_width]
						}.to raise_error Configuration::NoImageDataForVariableError, %q{image 'abc' does not have data for variable 'image_width'}
						expect {
							subject.with_locals(image_name: 'abc')[:image_height]
						}.to raise_error Configuration::NoImageDataForVariableError, %q{image 'abc' does not have data for variable 'image_height'}
					end
				end
			end

			it 'should raise ImageNotLoadedError if image lookup fails' do
				expect {
					Configuration::RequestState.new.images['test']
				}.to raise_error Configuration::ImageNotLoadedError, "image 'test' not loaded"
			end

			it 'should free memory limit if overwritting image' do
				limit = MemoryLimit.new(2)
				request_state = Configuration::RequestState.new('abc', {}, '', {}, limit)

				limit.borrow 1
				request_state.images['test'] = Configuration::Image.new('x')
				limit.limit.should == 1

				limit.borrow 1
				limit.limit.should == 0
				request_state.images['test'] = Configuration::Image.new('x')
				limit.limit.should == 1

				limit.borrow 1
				limit.limit.should == 0
				request_state.images['test'] = Configuration::Image.new('x')
				limit.limit.should == 1

				limit.borrow 1
				limit.limit.should == 0
				request_state.images['test2'] = Configuration::Image.new('x')
				limit.limit.should == 0
			end
		end

		describe 'sources' do
			it 'should have implicit InputSource on non get handlers' do
				subject.handlers[0].sources.first.should_not be_a Configuration::InputSource
				subject.handlers[1].sources.first.should be_a Configuration::InputSource
				subject.handlers[2].sources.first.should be_a Configuration::InputSource
			end

			describe Configuration::InputSource do
				it 'should copy input data to "input" image when realized' do
					state = Configuration::RequestState.new('abc')
					input_source = subject.handlers[1].sources[0].realize(state)
					state.images['input'].data.should == 'abc'
				end

				it 'should have nil mime type' do
					state = Configuration::RequestState.new('abc')
					input_source = subject.handlers[1].sources[0].realize(state)
					state.images['input'].mime_type.should be_nil
				end

				it 'should have nil source path and url' do
					state = Configuration::RequestState.new('abc')
					input_source = subject.handlers[1].sources[0].realize(state)
					state.images['input'].source_path.should be_nil
					state.images['input'].source_url.should be_nil
				end
			end
		end

		describe 'output' do
			it 'should default to OutputOK' do
				subject.handlers[0].output.should be_a Configuration::OutputOK
				subject.handlers[1].output.should be_a Configuration::OutputOK
				subject.handlers[2].output.should be_a Configuration::OutputOK
			end
		end
	end
end

