require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/file'
require 'httpimagestore/configuration/output'

describe Configuration do
	let :state do
		Configuration::RequestState.new('abc')
	end

	describe Configuration::FileSource do
		subject do
			Configuration.read(<<-EOF)
			path {
				"in"	"test.in"
			}

			get "small" {
				source_file "original" root="/tmp" path="in"
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

		it 'should source image from file using path spec' do
			subject.handlers[0].sources[0].should be_a Configuration::FileSource
			subject.handlers[0].sources[0].realize(state)

			state.images["original"].should_not be_nil
			state.images["original"].data.should == 'abc'
		end

		it 'should have nil mime type' do
			subject.handlers[0].sources[0].realize(state)

			state.images["original"].mime_type.should be_nil
		end

		it 'should have source path and url' do
			subject.handlers[0].sources[0].realize(state)

			state.images['original'].source_path.to_s.should == "test.in"
			state.images['original'].source_url.to_s.should == "file:/test.in"
		end

		describe 'context locals' do
			before :all do
				Pathname.new('/tmp/test-image-name.jpg').open('w') do |io|
					io.write('hello world')
				end
			end

			subject do
				Configuration.read(<<-EOF)
				path "image_name" "\#{image_name}.jpg"

				get "small" {
					source_file "test-image-name" root="/tmp" path="image_name"
				}
				EOF
			end

			it 'should provide image name to be used as #{image_name}' do
				subject.handlers[0].sources[0].realize(state)
				state.images['test-image-name'].source_path.to_s.should == 'test-image-name.jpg'
				state.images['test-image-name'].data.should == 'hello world'
			end
		end

		describe 'error handling' do
			it 'should raise StorageOutsideOfRootDirError on bad paths' do
				subject = Configuration.read(<<-EOF)
				path {
					"bad"	"../test.in"
				}

				get "bad_path" {
					source_file "original" root="/tmp" path="bad"
				}
				EOF

				expect {
					subject.handlers[0].sources[0].realize(state)
				}.to raise_error Configuration::FileStorageOutsideOfRootDirError, %{error while processing image 'original': file storage path '../test.in' outside of root direcotry}
			end

			it 'should raise NoSuchFileError on missing file' do
				subject = Configuration.read(<<-EOF)
				path {
					"missing"	"blah"
				}

				get "bad_path" {
					source_file "original" root="/tmp" path="missing"
				}
				EOF

				expect {
					subject.handlers[0].sources[0].realize(state)
				}.to raise_error Configuration::NoSuchFileError, %{error while processing image 'original': file 'blah' not found}
			end

			it 'should raise NoValueError on missing image name' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file root="/tmp" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'source_file path="hash" root="/tmp"': expected image name}
			end

			it 'should raise NoAttributeError on missing root argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file "original" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_file "original" path="hash"': expected 'root' attribute to be set}
			end

			it 'should raise NoAttributeError on missing path argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_file "original" root="/tmp"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_file "original" root="/tmp"': expected 'path' attribute to be set}
			end
		end

		describe 'memory limit' do
			let :state do
				Configuration::RequestState.new('abc', {}, '', {}, MemoryLimit.new(1))
			end

			it 'should rais MemoryLimit::MemoryLimitedExceededError error if limit exceeded runing file sourcing' do
				expect {
					subject.handlers[0].sources[0].realize(state)
				}.to raise_error MemoryLimit::MemoryLimitedExceededError, 'memory limit exceeded'
			end
		end

		context 'in failover context' do
			subject do
				Configuration.read(<<-EOF)
				path "in" "test.in"

				get "test" {
					source_failover {
						source_file "first_fail_1" root="/tmp/bogous" path="in"
						source_file "first_fail_2" root="/tmp" path="in"
					}
				}
				EOF
			end

			it 'should source second image' do
				subject.handlers[0].sources[0].should be_a Configuration::SourceFailover
				subject.handlers[0].sources[0].realize(state)

				state.images.keys.should == ['first_fail_2']
				state.images['first_fail_2'].should_not be_nil
				state.images['first_fail_2'].data.should == 'abc'
			end
		end
	end

	describe Configuration::FileStore do
		subject do
			Configuration.read(<<-EOF)
			path {
				"out"	"test.out"
			}

			post "small" {
				store_file "input" root="/tmp" path="out"
			}
			EOF
		end

		let :out_file do
			Pathname.new("/tmp/test.out")
		end

		before :each do
			out_file.unlink if out_file.exist?
			subject.handlers[0].sources[0].realize(state)
		end

		after :each do
			out_file.unlink if out_file.exist?
		end

		it 'should store image in file using path spec' do
			subject.handlers[0].stores[0].should be_a Configuration::FileStore
			subject.handlers[0].stores[0].realize(state)

			out_file.should exist
			out_file.read.should == 'abc'
		end

		it 'should have store path and url' do
			subject.handlers[0].stores[0].realize(state)

			state.images['input'].store_path.should == "test.out"
			state.images['input'].store_url.to_s.should == "file:/test.out"
		end

		describe 'conditional inclusion support' do
			subject do
				Configuration.read(<<-'EOF')
				path {
					"out"	"test.out"
				}

				post "small" {
					store_file "input1" root="/tmp" path="out" if-image-name-on="#{list}"
					store_file "input2" root="/tmp" path="out" if-image-name-on="#{list}"
					store_file "input3" root="/tmp" path="out" if-image-name-on="#{list}"
				}
				EOF
			end

			let :state do
				Configuration::RequestState.new('abc', {list: 'input1,input3'})
			end

			it 'should mark stores to ib included when image name match if-image-name-on list' do
				subject.handlers[0].stores[0].excluded?(state).should be_false
				subject.handlers[0].stores[1].excluded?(state).should be_true
				subject.handlers[0].stores[2].excluded?(state).should be_false
			end
		end

		describe 'context locals' do
			subject do
				Configuration.read(<<-'EOF')
				path "image_name" "#{image_name}.jpg"
				path "image_mime_extension" "test-store-file.#{image_mime_extension}"

				post "small" {
					store_file "input" root="/tmp" path="image_name"
					store_file "input" root="/tmp" path="image_mime_extension"
				}
				EOF
			end

			it 'should provide image name to be used as #{image_name}' do
				subject.handlers[0].stores[0].realize(state)

				state.images['input'].store_path.should == 'input.jpg'
			end

			it 'should provide image mime type based file extension to be used as #{image_mime_extension}' do
				state.images['input'].mime_type = 'image/jpeg'
				subject.handlers[0].stores[1].realize(state)

				state.images['input'].store_path.should == 'test-store-file.jpg'
			end

			it 'should raise PathRenderingError if there is on mime type for image defined and path contains #{image_mime_extension}' do
				expect {
					subject.handlers[0].stores[1].realize(state)
				}.to raise_error Configuration::PathRenderingError, %q{cannot generate path 'image_mime_extension' from template 'test-store-file.#{image_mime_extension}': image 'input' does not have data for variable 'image_mime_extension'}
			end
		end

		describe 'error handling' do
			it 'should raise StorageOutsideOfRootDirError on bad paths' do
				subject = Configuration.read(<<-EOF)
				path {
					"bad"	"../test.in"
				}

				post "bad_path" {
					store_file "input" root="/tmp" path="bad"
				}
				EOF

				expect {
					subject.handlers[0].stores[0].realize(state)
				}.to raise_error Configuration::FileStorageOutsideOfRootDirError, %{error while processing image 'input': file storage path '../test.in' outside of root direcotry}
			end

			it 'should raise NoValueError on missing image name' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						store_file root="/tmp" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'store_file path="hash" root="/tmp"': expected image name}
			end

			it 'should raise NoAttributeError on missing root argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						store_file "original" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'store_file "original" path="hash"': expected 'root' attribute to be set}
			end

			it 'should raise NoAttributeError on missing path argument' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						store_file "original" root="/tmp"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'store_file "original" root="/tmp"': expected 'path' attribute to be set}
			end
		end
	end
end

