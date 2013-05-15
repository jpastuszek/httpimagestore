require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	describe 'file source and store' do
		subject do
			Configuration.from_file(support_dir + 'file.cfg')
		end

		it 'should source image from file and store image in file using path spec' do
			in_file = Pathname.new("/tmp/test.in")
			out_file = Pathname.new("/tmp/test.out")

			in_file.open('w'){|io| io.write('abc')}
			out_file.unlink if out_file.exist?

			subject.handlers[0].image_sources[0].should be_a Configuration::FileSource

			state = Configuration::RequestState.new
			subject.handlers[0].image_sources[0].realize(state)

			state.images["original"].should_not be_nil
			state.images["original"].data.should == 'abc'
			state.images["original"].mime_type.should be_nil

			subject.handlers[0].stores[0].should be_a Configuration::FileStore
			subject.handlers[0].stores[0].realize(state)

			out_file.should exist
			out_file.read.should == 'abc'

			out_file.unlink
			in_file.unlink
		end

		it 'should raise StorageOutsideOfRootDirError on bad paths' do
			state = Configuration::RequestState.new
			expect {
				subject.handlers[1].image_sources[0].realize(state)
			}.to raise_error Configuration::FileStorageOutsideOfRootDirError, %{error while processing image 'original': file storage path '../test.in' outside of root direcotry}
		end

		describe 'error handling' do
			it 'should raise error on missing image name' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file root="/tmp" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'source_file path="hash" root="/tmp"': expected image name}
			end

			it 'should raise error on missing root argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file "original" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_file "original" path="hash"': expected 'root' attribute to be set}
			end

			it 'should raise error on missing path argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file "original" root="/tmp"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_file "original" root="/tmp"': expected 'path' attribute to be set}
			end
		end
	end
end

