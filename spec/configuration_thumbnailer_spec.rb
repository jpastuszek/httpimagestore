require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/thumbnailer'

describe Configuration do
	describe 'thumbnailer' do
		subject do
			Configuration.read('')
		end

		it 'should provide HTTPThumbnailerClient' do
			subject.thumbnailer.should be_a HTTPThumbnailerClient
		end

		it 'should use default URL' do
			subject.thumbnailer.server_url.should == 'http://localhost:3100'
		end

		it 'should allow to override default URL' do
			subject = Configuration.read(<<-EOF, thumbnailer_url: 'http://1.1.1.1:8080')
			EOF

			subject.thumbnailer.server_url.should == 'http://1.1.1.1:8080'
		end

		it 'should get thumbnailer URL from configuration' do
			subject = Configuration.read(<<-EOF, thumbnailer_url: 'http://1.1.1.1:8080')
			thumbnailer url="http://2.2.2.2:1000"
			EOF
			
			subject.thumbnailer.server_url.should == 'http://2.2.2.2:1000'
		end

		describe 'error handling' do
			it 'should raise StatementCollisionError on duplicate thumbnailer statement' do
				expect {
					Configuration.read(<<-EOF)
					thumbnailer url="http://2.2.2.2:1000"
					thumbnailer url="http://2.2.2.2:1000"
					EOF
				}.to raise_error Configuration::StatementCollisionError, %{syntax error while parsing 'thumbnailer url="http://2.2.2.2:1000"': only one thumbnailer type statement can be specified within context}
			end

			it 'should raise NoAttributeError on missing url attribute' do
				expect {
					Configuration.read(<<-EOF)
					thumbnailer
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'thumbnailer': expected 'url' attribute to be set}
			end
		end
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

			describe 'error handling' do
				it 'should raise NoValueForSpecTemplatePlaceholerError on missing spec template value' do
					locals = {
						width: 99,
						height: 66,
						format: 'png'
					}

					expect {
						Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}').render(locals)
					}.to raise_error Configuration::NoValueForSpecTemplatePlaceholerError, %q{cannot generate specification for thumbnail 'small': cannot generate value for attribute 'method' from template '#{operation}': no value for #{operation}}
				end

				it 'should raise NoValueForSpecTemplatePlaceholerError on missing option template value' do
					locals = {
						width: 99,
						height: 66,
						format: 'png',
					}

					expect {
						Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'background-color' => '#{bg}').render(locals)
					}.to raise_error Configuration::NoValueForSpecTemplatePlaceholerError, %q{cannot generate specification for thumbnail 'small': cannot generate value for attribute 'background-color' from template '#{bg}': no value for #{bg}}
				end
			end
		end

		describe 'thumbnail source image' do
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
					(support_dir + 'compute.jpg').read,
					operation: 'pad',
					width: '10',
					height: '10',
					options: 'background-color:green',
					path: nil
				)
			end

			before :each do
				subject.handlers[0].image_sources[0].realize(state)
			end

			describe 'thumbnailing to single spec' do
				subject do
					Configuration.read(<<-'EOF')
					put ":operation" ":width" ":height" ":options" {
						thumbnail "input" "original" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"
					}
					EOF
				end

				before :each do
					state.images['input'].source_path = 'test.in'
					state.images['input'].source_url = 'file://test.in'
					subject.handlers[0].image_sources[1].realize(state)
				end

				it 'should provide thumbnail data' do
					state.images['original'].data.should_not be_nil
				end

				it 'should set thumbnail mime type' do
					state.images['original'].mime_type.should == 'image/jpeg'
				end

				it 'should use input image source path and url' do
					state.images['original'].source_path.should == 'test.in'
					state.images['original'].source_url.should == 'file://test.in'
				end

				it 'should set input image mime type' do
					state.images['input'].mime_type.should == 'image/jpeg'
				end

				describe 'error handling' do
					it 'should raise Thumbnail::ThumbnailingError on realization of bad thumbnail sepc' do
						state = Configuration::RequestState.new(
							(support_dir + 'compute.jpg').read,
							operation: 'pad',
							width: '0',
							height: '10',
							options: 'background-color:green',
							path: nil
						)

						expect {
							subject.handlers[0].image_sources[0].realize(state)
							subject.handlers[0].image_sources[1].realize(state)
						}.to raise_error Configuration::Thumbnail::ThumbnailingError, "thumbnailing of 'input' into 'original' failed: at least one image dimension is zero: 0x10"
					end

					it 'should raise NoValueError on missing source image name' do
						expect {
							Configuration.read(<<-EOF)
							put {
								thumbnail
							}
							EOF
						}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'thumbnail': expected source image name}
					end

					it 'should raise NoValueError on missing source image name' do
						expect {
							Configuration.read(<<-EOF)
							put {
								thumbnail "input"
							}
							EOF
						}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'thumbnail "input"': expected thumbnail image name}
					end
				end
			end

			describe 'thumbnailing to multiple specs' do
				subject do
					Configuration.read(<<-'EOF')
					put ":operation" ":width" ":height" ":options" {
						thumbnail "input" {
							"original" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"
							"small"		operation="crop"	width=128	height=128	format="jpeg"
							"padded"	operation="pad"		width=128	height=128	format="png"	background-color="gray"
						}
					}
					EOF
				end

				before :each do
					state.images['input'].source_path = 'test.in'
					state.images['input'].source_url = 'file://test.in'
					subject.handlers[0].image_sources[1].realize(state)
				end

				it 'should provide thumbnail data' do
					state.images['original'].data.should_not be_nil
					state.images['small'].data.should_not be_nil
					state.images['padded'].data.should_not be_nil
				end

				it 'should set thumbnail mime type' do
					state.images['original'].mime_type.should == 'image/jpeg'
					state.images['small'].mime_type.should == 'image/jpeg'
					state.images['padded'].mime_type.should == 'image/png'
				end

				it 'should set input image mime type' do
					state.images['input'].mime_type.should == 'image/jpeg'
				end

				it 'should use input image source path and url' do
					state.images['original'].source_path.should == 'test.in'
					state.images['original'].source_url.should == 'file://test.in'
					state.images['small'].source_path.should == 'test.in'
					state.images['small'].source_url.should == 'file://test.in'
					state.images['padded'].source_path.should == 'test.in'
					state.images['padded'].source_url.should == 'file://test.in'
				end

				describe 'if image name on support' do
					subject do 
						Configuration.read(<<-'EOF')
						put {
							thumbnail "input" {
								"original"	if-image-name-on="#{list}"
								"small"			if-image-name-on="#{list}"
								"padded"		if-image-name-on="#{list}"
							}
						}
						EOF
					end

					let :state do
						Configuration::RequestState.new(
							(support_dir + 'compute.jpg').read,
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green',
							path: nil,
							list: 'small,padded'
						)
					end

					it 'should provide thumbnails only when name match comma separated name list' do
						state.images.should_not include 'original'
						state.images['small'].data.should_not be_nil
						state.images['padded'].data.should_not be_nil
					end
				end

				describe 'error handling' do
					it 'should raise Thumbnail::ThumbnailingError on realization of bad thumbnail sepc' do
						state = Configuration::RequestState.new(
							(support_dir + 'compute.jpg').read,
							operation: 'pad',
							width: '0',
							height: '10',
							options: 'background-color:green',
							path: nil
						)

						subject.handlers[0].image_sources[0].realize(state)

						expect {
							subject.handlers[0].image_sources[1].realize(state)
						}.to raise_error Configuration::Thumbnail::ThumbnailingError, "thumbnailing of 'input' into 'original' failed: at least one image dimension is zero: 0x10"
					end

					it 'should raise NoValueError on missing source image name' do
						expect {
							Configuration.read(<<-EOF)
							put {
								thumbnail {
								}
							}
							EOF
						}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'thumbnail': expected source image name}
					end
				end
			end
		end

		describe 'if image name on support' do
			let :state do
				Configuration::RequestState.new(
					(support_dir + 'compute.jpg').read,
					list: 'thumbnail1,input4'
				)
			end

			subject do
				Configuration.read(<<-'EOF')
				put {
					thumbnail "input1" "thumbnail1" if-image-name-on="#{list}"
					thumbnail "input2" "thumbnail2" if-image-name-on="#{list}"
					thumbnail "input3" if-image-name-on="#{list}" {
						"thumbnail3" 
					}
					thumbnail "input4" if-image-name-on="#{list}" {
						"thumbnail4" 
					}
				}
				EOF
			end

			it 'should mark source to be excluded by list using output image name in oneline and destination image name in multiline statement' do
				subject.handlers[0].image_sources[1].excluded?(state).should be_false
				subject.handlers[0].image_sources[2].excluded?(state).should be_true
				subject.handlers[0].image_sources[3].excluded?(state).should be_true
				subject.handlers[0].image_sources[4].excluded?(state).should be_false
			end
		end
	end
end

