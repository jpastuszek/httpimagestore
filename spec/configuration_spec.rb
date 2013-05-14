require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	subject do
		Configuration.from_file(support_dir + 'minimum.cfg')
	end

	it 'should parse configuration file' do
		subject
	end

	describe 'path specs' do
		it 'should load path and render spec templates' do
			subject.path['uri'].render(path: 'test/abc.jpg').should == 'test/abc.jpg'
			subject.path['hash'].render(path: 'test/abc.jpg', image_data: 'hello').should == '2cf24dba5fb0a30e.jpg'
			subject.path['hash-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == '2cf24dba5fb0a30e/xbrna.jpg'
			subject.path['structured'].render(path: 'test/abc.jpg', image_data: 'hello').should == 'test/2cf24dba5fb0a30e/abc.jpg'
			subject.path['structured-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == 'test/2cf24dba5fb0a30e/abc-xbrna.jpg'
		end
	end

	describe 'thumbnailer' do
		it 'should provide default URL' do
			subject.thumbnailer.url.should == 'http://localhost:3100'
		end

		it 'should allow to override default URL' do
			subject = Configuration.from_file(support_dir + 'minimum.cfg', thumbnailer_url: 'http://1.1.1.1:8080')
			subject.thumbnailer.url.should == 'http://1.1.1.1:8080'
		end

		it 'should get thumbnailer URL from configuration' do
			subject = Configuration.read('thumbnailer url="http://2.2.2.2:1000"')
			subject.thumbnailer.url.should == 'http://2.2.2.2:1000'
		end

		it 'should provide HTTPThumbnailerClient' do
			subject.thumbnailer.client.should be_a HTTPThumbnailerClient
			subject.thumbnailer.client.server_url.should == 'http://localhost:3100'
		end

		describe Configuration::Thumbnail::ThumbnailSpec do
			describe 'should provide thumbnail spec array based on given locals' do
				it 'where image name is hash key pointing to array where all values are string and options is hash' do
					Configuration::Thumbnail::ThumbnailSpec.new('small', 'pad', 100, 100, 'jpeg', 'background-color' => 'red').render.should == {
						'small' => 
							['pad', '100', '100', 'jpeg', {'background-color' => 'red'}]
					}
				end

				describe 'that are templated' do
					it 'with local values for operation, width, height and values of options' do
						locals = {
							operation: 'fit',
							width: 99,
							height: 66,
							format: 'png',
							bg: 'white'
						}

						Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'background-color' => '#{bg}').render(locals).should == {
							'small' => 
								['fit', '99', '66', 'png', {'background-color' => 'white'}]
						}
					end

					it 'with nested options provided by options key in <key>:<value>[,<key>:<value>]* format but not overwriting predefined options' do
						locals = {
							operation: 'fit',
							width: 99,
							height: 66,
							format: 'png',
							opts: 'background-color:blue,quality:100'
						}

						Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'options' => '#{opts}', 'background-color' => 'red').render(locals).should == {
							'small' => 
								['fit', '99', '66', 'png', {'background-color' => 'red', 'quality' => '100'}]
						}
					end
				end
			end
		end
	end

	describe 'handlers' do
		it 'should provide request matchers' do
			subject.handlers[0].matchers.should == ['get', 'thumbnail', 'v1', :operation, :width, :height, :options]
			subject.handlers[1].matchers.should == ['put', 'thumbnail', 'v1', :operation, :width, :height, :options]
		end

		describe 'sources' do
			before :all do
				log = support_dir + 'server.log'
				start_server(
					"httpthumbnailer -f -d -l #{log}",
					'/tmp/httpthumbnailer.pid',
					log,
					'http://localhost:3100/'
				)
			end

			it 'should have implicit InputSource on non get handlers' do
				subject.handlers[0].image_sources.first.should_not be_a Configuration::InputSource
				subject.handlers[1].image_sources.first.should be_a Configuration::InputSource
			end

			it 'should realize input source' do
				input_source = subject.handlers[1].image_sources.first
				state = Configuration::RequestState.new('abc')
				input_source.realize(state)
				state.images['input'].data.should == 'abc'
			end

			it 'should realize thumbnailer source and set input image mime type' do
				state = Configuration::RequestState.new(
					(support_dir + 'compute.jpg').read,
					operation: 'pad',
					width: '10',
					height: '10',
					options: 'background-color:green',
					path: nil
				)

				# need input image
				subject.handlers[1].image_sources[0].realize(state)
				state.images['input'].data.should_not be_nil
				state.images['input'].mime_type.should be_nil

				# thumbanil
				subject.handlers[1].image_sources[1].realize(state)
				state.images['original'].data.should_not be_nil
				state.images['original'].mime_type.should == 'image/jpeg'

				state.images['input'].mime_type.should == 'image/jpeg'
			end

			it 'should fail on realizin bad thumbnail sepc thumbnailing' do
				state = Configuration::RequestState.new(
					(support_dir + 'compute.jpg').read,
					operation: 'pad',
					width: '0',
					height: '10',
					options: 'background-color:green',
					path: nil
				)

				# need input image
				subject.handlers[1].image_sources[0].realize(state)

				expect {
					subject.handlers[1].image_sources[1].realize(state)
				}.to raise_error Configuration::Thumbnail::ThumbnailingError, "thumbnailing of 'input' into 'original' failed: at least one image dimension is zero: 0x10"
			end
		end
	end
end

