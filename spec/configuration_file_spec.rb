require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/file'

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
			subject.handlers[0].image_sources[0].should be_a Configuration::FileSource
			subject.handlers[0].image_sources[0].realize(state)

			state.images["original"].should_not be_nil
			state.images["original"].data.should == 'abc'
		end

		it 'should have nil mime type' do
			subject.handlers[0].image_sources[0].realize(state)

			state.images["original"].mime_type.should be_nil
		end

		it 'should have source path and url' do
			subject.handlers[0].image_sources[0].realize(state)

			state.images['original'].source_path.should == "/tmp/test.in"
			state.images['original'].source_url.should == "file:///tmp/test.in"
		end

		describe 'context locals' do
			before :all do
				Pathname.new('/tmp/test-image-name.jpg').open('w') do |io|
					io.write('hello world')
				end
			end
			
			subject do
				Configuration.read(<<-EOF)
				path "imagename" "\#{imagename}.jpg"

				get "small" {
					source_file "test-image-name" root="/tmp" path="imagename"
				}
				EOF
			end

			it 'should provide image name to be used as #{imagename}' do
				subject.handlers[0].image_sources[0].realize(state)
				state.images['test-image-name'].source_path.should == '/tmp/test-image-name.jpg'
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
					subject.handlers[0].image_sources[0].realize(state)
				}.to raise_error Configuration::FileStorageOutsideOfRootDirError, %{error while processing image 'original': file storage path '../test.in' outside of root direcotry}
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
			subject.handlers[0].image_sources[0].realize(state)
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

			state.images['input'].store_path.should == "/tmp/test.out"
			state.images['input'].store_url.should == "file:///tmp/test.out"
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
				Configuration::RequestState.new('abc', list: 'input1,input3')
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
				path "imagename" "#{imagename}.jpg"
				path "mimeextension" "test-store-file.#{mimeextension}"

				post "small" {
					store_file "input" root="/tmp" path="imagename"
					store_file "input" root="/tmp" path="mimeextension"
				}
				EOF
			end

			it 'should provide image name to be used as #{imagename}' do
				subject.handlers[0].stores[0].realize(state)

				state.images['input'].store_path.should == '/tmp/input.jpg'
			end
			
			it 'should provide image mime type based file extension to be used as #{mimeextension}' do
				state.images['input'].mime_type = 'image/jpeg'
				subject.handlers[0].stores[1].realize(state)

				state.images['input'].store_path.should == '/tmp/test-store-file.jpg'
			end

			it 'should raise NoValueForPathTemplatePlaceholerError if there is on mime type for image defined and path contains #{mimeextension}' do
				expect {
					subject.handlers[0].stores[1].realize(state)
				}.to raise_error Configuration::NoValueForPathTemplatePlaceholerError, %q{cannot generate path 'mimeextension' from template 'test-store-file.#{mimeextension}': no value for '#{mimeextension}'}
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

