require_relative 'spec_helper'
require_relative 'support/cuba_response_env'

require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/output'

describe Configuration do
	describe 'image output' do
		subject do
			Configuration.read(<<-EOF)
			put "test" {
				output_image "input"
			}
			EOF
		end

		it 'should provide given image' do
			subject.handlers[0].output.should be_a Configuration::OutputImage
			subject.handlers[0].image_sources[0].should be_a Configuration::InputSource

			state = Configuration::RequestState.new('abc')
			subject.handlers[0].image_sources[0].realize(state)
			subject.handlers[0].output.realize(state)

			env = CubaResponseEnv.new

			env.instance_eval &state.output_callback
			env.res.status.should == 200
			env.res.data.should == 'abc'
		end

		it 'should use default content type if not defined on image' do
			state = Configuration::RequestState.new('abc')
			subject.handlers[0].image_sources[0].realize(state)
			subject.handlers[0].output.realize(state)

			env = CubaResponseEnv.new

			env.instance_eval &state.output_callback
			env.res['Content-Type'].should == 'application/octet-stream'
		end

		it 'should use image mime type if available' do
			state = Configuration::RequestState.new('abc')
			subject.handlers[0].image_sources[0].realize(state)

			state.images['input'].mime_type = 'image/jpeg'
			subject.handlers[0].output.realize(state)

			env = CubaResponseEnv.new

			env.instance_eval &state.output_callback
			env.res['Content-Type'].should == 'image/jpeg'
		end
	end
end

