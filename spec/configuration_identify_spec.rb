require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/output'
require 'httpimagestore/configuration/thumbnailer'
require 'httpimagestore/configuration/identify'

describe Configuration do
	describe 'identify' do
		before :all do
			log = support_dir + 'server.log'
			start_server(
				"httpthumbnailer -f -d -x XID -l #{log}",
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
			subject.handlers[0].sources[0].realize(state)
			state.images['input'].mime_type.should be_nil

			subject.handlers[0].processors[0].realize(state)
			state.images['input'].mime_type.should == 'image/jpeg'
		end

		describe 'passing HTTP headers to thumbnailer' do
			let :xid do
				rand(0..1000)
			end

			let :state do
				Configuration::RequestState.new(
					(support_dir + 'compute.jpg').read,
					{}, '', {}, MemoryLimit.new,
					{'XID' => xid}
				)
			end

			it 'should pass headers provided with request state' do
				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].processors[0].realize(state)
				state.images['input'].mime_type.should == 'image/jpeg'

				(support_dir + 'server.log').read.should include "\"xid\":\"#{xid}\""
			end
		end
	end
end


