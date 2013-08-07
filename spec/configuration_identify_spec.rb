require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/thumbnailer'
require 'httpimagestore/configuration/identify'
MemoryLimit.logger = Logger.new('/dev/null')

describe Configuration do
	describe 'thumbnailer' do
		before :all do
			log = support_dir + 'server.log'
			start_server(
				"httpthumbnailer -f -d -l #{log}",
				'/tmp/httpthumbnailer.pid',
				log,
				'http://localhost:3100/'
			)
		end

		let :state do
			Configuration::RequestState.new(
				(support_dir + 'compute.jpg').read
			)
		end

		subject do
			Configuration.read(<<-'EOF')
			put {
				identify "input"
			}
			EOF
		end

		it 'should provide input image mime type' do
			subject.handlers[0].image_sources[0].realize(state)
			state.images['input'].mime_type.should be_nil

			subject.handlers[0].image_sources[1].realize(state)
			state.images['input'].mime_type.should == 'image/jpeg'
		end
	end
end


