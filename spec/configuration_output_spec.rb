require_relative 'spec_helper'
require_relative 'support/cuba_response_env'

require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/output'
require 'httpimagestore/configuration/file'

describe Configuration do
	let :state do
		Configuration::RequestState.new('abc')
	end

	let :env do
		CubaResponseEnv.new
	end

	describe Configuration::OutputImage do
		subject do
			Configuration.read(<<-EOF)
			put "test" {
				output_image "input"
			}
			EOF
		end

		before :each do
			subject.handlers[0].image_sources[0].realize(state)
		end

		it 'should provide given image' do
			subject.handlers[0].output.should be_a Configuration::OutputImage
			subject.handlers[0].output.realize(state)

			env.instance_eval &state.output_callback
			env.res.status.should == 200
			env.res.data.should == 'abc'
		end

		it 'should use default content type if not defined on image' do
			subject.handlers[0].output.realize(state)

			env.instance_eval &state.output_callback
			env.res['Content-Type'].should == 'application/octet-stream'
		end

		it 'should use image mime type if available' do
			state.images['input'].mime_type = 'image/jpeg'

			subject.handlers[0].output.realize(state)

			env.instance_eval &state.output_callback
			env.res['Content-Type'].should == 'image/jpeg'
		end
	end

	describe 'output store paths and URLs' do
		let :in_file do
			Pathname.new("/tmp/test.in")
		end

		let :out_file do
			Pathname.new("/tmp/test.out")
		end

		let :out2_file do
			Pathname.new("/tmp/test.out2")
		end

		before :each do
			in_file.open('w'){|io| io.write('abc')}
			out_file.unlink if out_file.exist?
			out2_file.unlink if out2_file.exist?
		end

		after :each do
			out_file.unlink if out_file.exist?
			out2_file.unlink if out2_file.exist?
			in_file.unlink
		end

		describe Configuration::OutputStorePath do
			it 'should provide file store path' do
				subject = Configuration.read(<<-EOF)
				path {
					"out"	"test.out"
				}

				post "single" {
					store_file "input" root="/tmp" path="out"

					output_store_path "input"
				}
				EOF

				subject.handlers[0].image_sources[0].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "/tmp/test.out\r\n"
			end

			it 'should provide multiple file store paths' do
				subject = Configuration.read(<<-EOF)
				path {
					"in"	"test.in"
					"out"	"test.out"
					"out2"	"test.out2"
				}

				post "multi" {
					source_file "original" root="/tmp" path="in"

					store_file "input" root="/tmp" path="out"
					store_file "original" root="/tmp" path="out2"

					output_store_path {
						"input"
						"original"
					}
				}
				EOF

				subject.handlers[0].image_sources[0].realize(state)
				subject.handlers[0].image_sources[1].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].stores[1].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "/tmp/test.out\r\n/tmp/test.out2\r\n"
			end

			describe 'error handling' do
				it 'should raise StorePathNotSetForImage for output of not stored image' do
					subject = Configuration.read(<<-EOF)
					post "single" {
						output_store_path "input"
					}
					EOF

					subject.handlers[0].image_sources[0].realize(state)

					expect {
						subject.handlers[0].output.realize(state)
					}.to raise_error Configuration::StorePathNotSetForImage, %{store path not set for image 'input'}
				end
			end
		end

		describe Configuration::OutputStoreURL do
			it 'should provide file store URL' do
				subject = Configuration.read(<<-EOF)
				path {
					"out"	"test.out"
				}

				post "single" {
					store_file "input" root="/tmp" path="out"

					output_store_url "input"
				}
				EOF

				subject.handlers[0].image_sources[0].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "file:///tmp/test.out\r\n"
			end

			it 'should provide multiple file store URLs' do
				subject = Configuration.read(<<-EOF)
				path {
					"in"	"test.in"
					"out"	"test.out"
					"out2"	"test.out2"
				}

				post "multi" {
					source_file "original" root="/tmp" path="in"

					store_file "input" root="/tmp" path="out"
					store_file "original" root="/tmp" path="out2"

					output_store_url {
						"input"
						"original"
					}
				}
				EOF

				subject.handlers[0].image_sources[0].realize(state)
				subject.handlers[0].image_sources[1].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].stores[1].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "file:///tmp/test.out\r\nfile:///tmp/test.out2\r\n"
			end

			describe 'error handling' do
				it 'should raise StoreURLNotSetForImage for output of not stored image' do
					subject = Configuration.read(<<-EOF)
					post "single" {
						output_store_url "input"
					}
					EOF

					subject.handlers[0].image_sources[0].realize(state)

					expect {
						subject.handlers[0].output.realize(state)
					}.to raise_error Configuration::StoreURLNotSetForImage, %{store URL not set for image 'input'}
				end
			end
		end
	end
end
