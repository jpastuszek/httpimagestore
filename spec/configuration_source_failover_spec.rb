require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/source_failover'
require 'httpimagestore/configuration/file'
require 'httpimagestore/configuration/output'
MemoryLimit.logger = Logger.new('/dev/null')

describe Configuration do
	let :state do
		request_state do |rs|
			rs.body 'abc'
		end
	end

	describe Configuration::FileSource do
		subject do
			Configuration.read(<<-EOF)
			path "in" "test.in"

			get "test" {
				source_failover {
					source_file "no_fail_1" root="/tmp" path="in"
					source_file "no_fail_2" root="/tmp" path="in"
				}

				source_failover {
					source_file "first_fail_1" root="/tmp/bogous" path="in"
					source_file "first_fail_2" root="/tmp" path="in"
				}

				source_failover {
					source_file "all_fail" root="/tmp/bogous" path="in"
					source_file "all_fail" root="/tmp/bogous2" path="in"
				}

				source_failover {
					source_file "deep_fail_1" root="/tmp/bogous" path="in"
					source_file "deep_fail_2" root="/tmp/bogous" path="in"
					source_file "deep_fail_3" root="/tmp" path="in"
					source_file "deep_fail_4" root="/tmp/bogous" path="in"
				}
			}
			EOF
		end

		let :in_file do
			Pathname.new("/tmp/test.in")
		end

		before :each do
			in_file.open('w'){|io| io.write('abc')}
		end

		after :each do
			in_file.unlink
		end

		context 'first source is OK' do
			it 'should source first image' do
				subject.handlers[0].sources[0].should be_a Configuration::SourceFailover
				subject.handlers[0].sources[0].realize(state)

				state.images.keys.should == ['no_fail_1']
				state.images['no_fail_1'].should_not be_nil
				state.images['no_fail_1'].data.should == 'abc'
			end
		end

		context 'second source is OK' do
			it 'should source second image' do
				subject.handlers[0].sources[1].should be_a Configuration::SourceFailover
				subject.handlers[0].sources[1].realize(state)

				state.images.keys.should == ['first_fail_2']
				state.images['first_fail_2'].should_not be_nil
				state.images['first_fail_2'].data.should == 'abc'
			end
		end

		context 'all sources fail' do
			it 'should raise error Configuration::SourceFailoverAllFailedError' do
				subject.handlers[0].sources[2].should be_a Configuration::SourceFailover

				expect {
					subject.handlers[0].sources[2].realize(state)
				}.to raise_error Configuration::SourceFailoverAllFailedError, "all sources failed: FileSource[image_name: 'all_fail' root_dir: '/tmp/bogous' path_spec: 'in'](Configuration::NoSuchFileError: error while processing image 'all_fail': file 'test.in' not found), FileSource[image_name: 'all_fail' root_dir: '/tmp/bogous2' path_spec: 'in'](Configuration::NoSuchFileError: error while processing image 'all_fail': file 'test.in' not found)"
			end
		end

		context 'tird source is OK' do
			it 'should source second image' do
				subject.handlers[0].sources[3].should be_a Configuration::SourceFailover
				subject.handlers[0].sources[3].realize(state)

				state.images.keys.should == ['deep_fail_3']
				state.images['deep_fail_3'].should_not be_nil
				state.images['deep_fail_3'].data.should == 'abc'
			end
		end
	end
end
