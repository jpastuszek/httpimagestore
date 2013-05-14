require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	subject do
		Configuration.from_file(support_dir + 'handler.cfg')
	end

	describe 'handlers' do
		it 'should provide request http_method and uri_matchers' do
			subject.handlers.length.should == 3

			subject.handlers[0].http_method.should == 'get'
			subject.handlers[0].uri_matchers.should == ['thumbnail', 'v1', :operation, :width, :height, :options]

			subject.handlers[1].http_method.should == 'put'
			subject.handlers[1].uri_matchers.should == ['thumbnail', 'v1', :operation, :width, :height, :options]

			subject.handlers[2].http_method.should == 'post'
			subject.handlers[2].uri_matchers.should be_empty
		end

		describe 'sources' do
			it 'should have implicit InputSource on non get handlers' do
				subject.handlers[0].image_sources.first.should_not be_a Configuration::InputSource
				subject.handlers[1].image_sources.first.should be_a Configuration::InputSource
				subject.handlers[2].image_sources.first.should be_a Configuration::InputSource
			end

			it 'should realize input source' do
				input_source = subject.handlers[1].image_sources.first
				state = Configuration::RequestState.new('abc')
				input_source.realize(state)
				state.images['input'].data.should == 'abc'
			end
		end

		describe 'output' do
			it 'should default to OutputOK' do
				subject.handlers[0].output.should_not be_a Configuration::OutputOK
				subject.handlers[1].output.should_not be_a Configuration::OutputOK
				subject.handlers[2].output.should be_a Configuration::OutputOK
			end
		end
	end
end

