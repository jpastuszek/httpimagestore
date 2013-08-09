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
				subject.handlers[0].uri_matchers.map{|m| m.name}.should == [nil, nil, :operation, :width, :height, :options]

				subject.handlers[1].http_method.should == 'put'
				subject.handlers[1].uri_matchers.map{|m| m.name}.should == [nil, nil, :test]

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

				it 'should provide query string params' do
					subject[:width].should == '123'
					subject[:height].should == '321'
				end

				it 'should provide matches' do
					subject[:operation].should == 'pad'
				end

				it 'should provide query_string_options' do
					subject[:query_string_options].should == 'height:321,width:123'
				end

				it 'should provide request body digest' do
					subject[:digest].should == '9f86d081884c7d65'
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

			describe Configuration::OutputOK do
				it 'should output 200 with OK text/plain message when realized' do
					state = Configuration::RequestState.new('abc')
					subject.handlers[2].output.realize(state)

					env = CubaResponseEnv.new
					env.instance_eval &state.output_callback
					env.res.status.should == 200
					env.res.data.should == "OK\r\n"
					env.res['Content-Type'].should == 'text/plain'
				end
			end
		end
	end
end

