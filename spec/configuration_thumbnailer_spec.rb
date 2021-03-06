require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/output'
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
		context 'when rendered' do
			context 'without placeholders' do
				subject do
					Configuration::Thumbnail::ThumbnailSpec.new('small', 'pad', '100', '102', 'JPEG', 'background-color' => 'red').render
				end

				it '#name should provide name of the spec' do
					subject.name.should == 'small'
				end

				describe '#spec' do
					it 'should provide full thumbnail spec with options' do
						subject.spec.method.should == 'pad'
						subject.spec.width.should == '100'
						subject.spec.height.should == '102'
						subject.spec.format.should == 'JPEG'
						subject.spec.options.should == {'background-color' => 'red'}
					end

					describe '#edits' do
						context 'when edits are provided as already parsed' do
							let :edit1 do
								Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('pad', ['0.1', '0.1', '0.8', '0.8'], {}, 1)
							end

							let :edit2 do
								Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('rotate', ['32'], {'background-color' => 'red'}, 2)
							end

							subject do
								Configuration::Thumbnail::ThumbnailSpec.new('small', 'pad', 100, 100, 'jpeg', {}, [edit1, edit2]).render.spec
							end

							it 'should provide list of edits to apply for to' do
								subject.edits.should have(2).edits

								subject.edits[0].name.should == 'pad'
								subject.edits[0].args.should have(4).argument
								subject.edits[0].args.should == ['0.1', '0.1', '0.8', '0.8']
								subject.edits[0].options.should == {}

								subject.edits[1].name.should == 'rotate'
								subject.edits[1].args.should have(1).argument
								subject.edits[1].args[0].should == '32'
								subject.edits[1].options.should == {'background-color' => 'red'}
							end

							context 'with arguments containing placeholders with existing locals' do
								let :edit1 do
									Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('fit', ['0.1', '0.1', '#{width}', '#{height}'], {}, 1)
								end

								let :edit2 do
									Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('rotate', ['#{angle}'], {'background-color' => '#{color}'}, 2)
								end

								subject do
									locals = {
										angle: 90,
										color: 'blue',
										width: 0.42,
										height: 0.34
									}
									Configuration::Thumbnail::ThumbnailSpec.new('small', 'pad', 100, 100, 'jpeg', {}, [edit1, edit2]).render(locals).spec
								end

								it 'should provide list of edits to apply for to with placeholders filled' do
									subject.edits.should have(2).edits

									subject.edits[0].name.should == 'fit'
									subject.edits[0].args.should have(4).argument
									subject.edits[0].args.should == ['0.1', '0.1', '0.42', '0.34']
									subject.edits[0].options.should == {}

									subject.edits[1].name.should == 'rotate'
									subject.edits[1].args.should have(1).argument
									subject.edits[1].args[0].should == '90'
									subject.edits[1].options.should == {'background-color' => 'blue'}
								end
							end
						end

						context 'when edits are provided unparsed as option edits' do
							subject do
								Configuration::Thumbnail::ThumbnailSpec.new('small', 'pad', 100, 100, 'jpeg', 'background-color' => 'red', 'edits' => 'rotate,30,background-color:red!crop,0.1,0.1,0.8,0.8').render.spec
							end

							it 'should provide list of edits to apply' do
								subject.edits.should have(2).edits

								subject.edits[0].name.should == 'rotate'
								subject.edits[0].args.should have(1).argument
								subject.edits[0].args[0].should == '30'
								subject.edits[0].options.should == {'background-color' => 'red'}

								subject.edits[1].name.should == 'crop'
								subject.edits[1].args.should have(4).argument
								subject.edits[1].args.should == ['0.1', '0.1', '0.8', '0.8']
								subject.edits[1].options.should == {}
							end
						end
					end
				end
			end

			context 'with placeholders to fill with locals' do
				context 'for method, width, height and options values' do
					subject do
						Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'background-color' => '#{bg}').render(
							operation: 'fit',
							width: 99,
							height: 66,
							format: 'png',
							bg: 'white'
						)
					end

					describe '#spec' do
						it 'should provide thumbnail spec with filled values' do
							subject.spec.method.should == 'fit'
							subject.spec.width.should == '99'
							subject.spec.height.should == '66'
							subject.spec.format.should == 'png'
							subject.spec.options.should == {'background-color' => 'white'}
						end
					end

					context 'and with options passed as options key via placeholder' do
						subject do
							Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'options' => '#{opts}').render(
								operation: 'fit',
								width: 99,
								height: 66,
								format: 'png',
								opts: 'background-color:blue,quality:100'
							).spec
						end

						describe '#spec' do
							it 'should provide thumbnail spec with options taken from filled options key that will not replace already provided values' do
								subject.options.should == {'background-color' => 'blue', 'quality' => '100'}
							end

							context 'with existing key' do
								subject do
									Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'options' => '#{opts}', 'background-color' => 'red').render(
										operation: 'fit',
										width: 99,
										height: 66,
										format: 'png',
										opts: 'background-color:blue,quality:100'
									).spec
								end
								it 'should not replace existing value' do
									subject.options.should == {'background-color' => 'red', 'quality' => '100'}
								end
							end
						end
					end

					context 'and with edits passed as options key via placeholder' do
						describe '#spec' do
							subject do
								Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'edits' => '#{ed}', 'background-color' => 'red').render(
									operation: 'fit',
									width: 99,
									height: 66,
									format: 'png',
									ed: 'rotate,30,background-color:red!crop,0.1,0.1,0.8,0.8'
								).spec
							end

							describe '#edits' do
								it 'should provide thumbnail spec with edits taken from filled edits key' do
									subject.edits.should have(2).edits

									subject.edits[0].name.should == 'rotate'
									subject.edits[0].args.should have(1).argument
									subject.edits[0].args[0].should == '30'
									subject.edits[0].options.should == {'background-color' => 'red'}

									subject.edits[1].name.should == 'crop'
									subject.edits[1].args.should have(4).argument
									subject.edits[1].args.should == ['0.1', '0.1', '0.8', '0.8']
									subject.edits[1].options.should == {}
								end

								context 'with already parsed edits' do
									let :edit1 do
										Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('pad', ['0.1', '0.1', '0.8', '0.8'], {}, 1)
									end

									let :edit2 do
										Configuration::Thumbnail::ThumbnailSpec::EditSpec.new('rotate', ['32'], {'background-color' => 'blue'}, 2)
									end

									subject do
										Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', {'edits' => '#{ed}', 'background-color' => 'red'}, [edit1, edit2]).render(
											operation: 'fit',
											width: 99,
											height: 66,
											format: 'png',
											ed: 'rotate,30,background-color:red!crop,0.1,0.1,0.8,0.8'
										).spec
									end

									it 'should add options provided edits after already parsed edits' do
										subject.edits.should have(4).edits

										subject.edits[0].name.should == 'pad'
										subject.edits[0].args.should have(4).argument
										subject.edits[0].args.should == ['0.1', '0.1', '0.8', '0.8']
										subject.edits[0].options.should == {}

										subject.edits[1].name.should == 'rotate'
										subject.edits[1].args.should have(1).argument
										subject.edits[1].args[0].should == '32'
										subject.edits[1].options.should == {'background-color' => 'blue'}

										subject.edits[2].name.should == 'rotate'
										subject.edits[2].args.should have(1).argument
										subject.edits[2].args[0].should == '30'
										subject.edits[2].options.should == {'background-color' => 'red'}

										subject.edits[3].name.should == 'crop'
										subject.edits[3].args.should have(4).argument
										subject.edits[3].args.should == ['0.1', '0.1', '0.8', '0.8']
										subject.edits[3].options.should == {}
									end
								end
							end
						end
					end

					describe 'error handling' do
						it 'should raise NoValueForSpecTemplatePlaceholderError on missing spec template value' do
							locals = {
								width: 99,
								height: 66,
								format: 'png'
							}

							expect {
								Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}').render(locals)
							}.to raise_error Configuration::NoValueForSpecTemplatePlaceholderError, %q{cannot generate specification for thumbnail 'small': cannot generate value for attribute 'method' from template '#{operation}': no value for #{operation}}
						end

						it 'should raise NoValueForSpecTemplatePlaceholderError on missing option template value' do
							locals = {
								width: 99,
								height: 66,
								format: 'png',
							}

							expect {
								Configuration::Thumbnail::ThumbnailSpec.new('small', '#{operation}', '#{width}', '#{height}', '#{format}', 'background-color' => '#{bg}').render(locals)
							}.to raise_error Configuration::NoValueForSpecTemplatePlaceholderError, %q{cannot generate specification for thumbnail 'small': cannot generate value for attribute 'background-color' from template '#{bg}': no value for #{bg}}
						end
					end
				end
			end
		end

		context 'with extra attributes' do
			it 'should raise UnexpectedAttributesError' do
				expect {
					Configuration.read(<<-'EOF')
					put {
						thumbnail "input4" blah="xyz" {
							"thumbnail5"
						}
					}
					EOF
				}.to raise_error Configuration::UnexpectedAttributesError
			end
		end
	end

	describe 'thumbnail source image' do
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
			request_state do |rs|
				rs.body((support_dir + 'compute.jpg').read)
				rs.matches(
					operation: 'pad',
					width: '10',
					height: '10',
					options: 'background-color:green'
				)
			end
		end

		before :each do
			subject.handlers[0].sources[0].realize(state)
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
			end

			it 'should provide thumbnail data' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].data.should_not be_nil
			end

			it 'should set thumbnail mime type' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].mime_type.should == 'image/jpeg'
			end

			it 'should use input image source path and url' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].source_path.should == 'test.in'
				state.images['original'].source_url.should == 'file://test.in'
			end

			it 'should set input image mime type' do
				subject.handlers[0].processors[0].realize(state)
				state.images['input'].mime_type.should == 'image/jpeg'
			end

			describe 'memory limit' do
				let :state do
					request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green'
						)
						rs.memory_limit MemoryLimit.new(10)
					end
				end

				it 'should raise MemoryLimit::MemoryLimitedExceededError when limit is exceeded' do
					expect {
						subject.handlers[0].processors[0].realize(state)
					}.to raise_error MemoryLimit::MemoryLimitedExceededError
				end
			end

			describe 'passing HTTP headers to thumbnailer' do
				let :xid do
					rand(0..1000)
				end

				let :state do
					request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green'
						)
						rs.forward_headers 'XID' => xid
					end
				end

				it 'should pass headers provided with request state' do
					subject.handlers[0].processors[0].realize(state)

					(support_dir + 'server.log').read.should include "\"xid\":\"#{xid}\""
				end
			end

			describe 'error handling' do
				it 'should raise Thumbnail::ThumbnailingError on realization of bad thumbnail sepc' do
					state = request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '0',
							height: '10',
							options: 'background-color:green'
						)
					end

					expect {
						subject.handlers[0].sources[0].realize(state)
						subject.handlers[0].processors[0].realize(state)
						}.to raise_error Configuration::Thumbnail::ThumbnailingError # WTF?, "thumbnailing of 'input' into 'original' failed: at least one image dimension is zero: 0x10"
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
			end

			it 'should provide thumbnail data' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].data.should_not be_nil
				state.images['small'].data.should_not be_nil
				state.images['padded'].data.should_not be_nil
			end

			it 'should set thumbnail mime type' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].mime_type.should == 'image/jpeg'
				state.images['small'].mime_type.should == 'image/jpeg'
				state.images['padded'].mime_type.should == 'image/png'
			end

			it 'should set input image mime type' do
				subject.handlers[0].processors[0].realize(state)
				state.images['input'].mime_type.should == 'image/jpeg'
			end

			it 'should use input image source path and url' do
				subject.handlers[0].processors[0].realize(state)
				state.images['original'].source_path.should == 'test.in'
				state.images['original'].source_url.should == 'file://test.in'
				state.images['small'].source_path.should == 'test.in'
				state.images['small'].source_url.should == 'file://test.in'
				state.images['padded'].source_path.should == 'test.in'
				state.images['padded'].source_url.should == 'file://test.in'
			end

			describe 'memory limit' do
				let :state do
					request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green'
						)
						rs.memory_limit MemoryLimit.new(10)
					end
				end

				it 'should raise MemoryLimit::MemoryLimitedExceededError when limit is exceeded' do
					expect {
						subject.handlers[0].processors[0].realize(state)
					}.to raise_error MemoryLimit::MemoryLimitedExceededError
				end
			end

			describe 'conditional inclusion support' do
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
					request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green',
							list: 'small,padded'
						)
					end
				end

				it 'should provide thumbnails that name match if-image-name-on list' do
					subject.handlers[0].processors[0].realize(state)
					state.images.should_not include 'original'
					state.images['small'].data.should_not be_nil
					state.images['padded'].data.should_not be_nil
				end
			end

			describe 'passing HTTP headers to thumbnailer' do
				let :xid do
					rand(0..1000)
				end

				let :state do
					request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '10',
							height: '10',
							options: 'background-color:green'
						)
						rs.forward_headers 'XID' => xid
					end
				end

				it 'should pass headers provided with request state' do
					subject.handlers[0].processors[0].realize(state)
					state.images.keys.should include 'original'
					state.images.keys.should include 'small'

					(support_dir + 'server.log').read.should include "\"xid\":\"#{xid}\""
				end
			end

			describe 'error handling' do
				it 'should raise Thumbnail::ThumbnailingError on realization of bad thumbnail sepc' do
					state = request_state do |rs|
						rs.body((support_dir + 'compute.jpg').read)
						rs.matches(
							operation: 'pad',
							width: '0',
							height: '10',
							options: 'background-color:green'
						)
					end

					subject.handlers[0].sources[0].realize(state)

					expect {
						subject.handlers[0].processors[0].realize(state)
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

	describe 'conditional inclusion support' do
		describe 'if-image-name-on' do
			let :state do
				request_state do |rs|
					rs.body((support_dir + 'compute.jpg').read)
					rs.matches list: 'thumbnail1,input4,thumbnail5,input6'
				end
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
					thumbnail "input5" if-image-name-on="#{list}" {
						"thumbnail5" if-image-name-on="#{list}"
					}
					thumbnail "input6" if-image-name-on="#{list}" {
						"thumbnail6" if-image-name-on="#{list}"
					}
				}
				EOF
			end

			it 'should mark source to be included when output image name in oneline and destination image name in multiline statement match if-image-name-on list' do
				subject.handlers[0].processors[0].excluded?(state).should be_false
				subject.handlers[0].processors[1].excluded?(state).should be_true
				subject.handlers[0].processors[2].excluded?(state).should be_true
				subject.handlers[0].processors[3].excluded?(state).should be_false
				subject.handlers[0].processors[4].excluded?(state).should be_true
				subject.handlers[0].processors[5].excluded?(state).should be_false
			end
		end

		describe 'if-variable-matches' do
			let :state do
				request_state do |rs|
					rs.body((support_dir + 'compute.jpg').read)
					rs.matches hello: 'world', xyz: 'true'
				end
			end

			subject do
				Configuration.read(<<-'EOF')
				put {
					thumbnail "input1" "thumbnail1" if-variable-matches="hello:world"
					thumbnail "input2" "thumbnail2" if-variable-matches="hello:blah"
					thumbnail "input1" "thumbnail1" if-variable-matches="xyz"
					thumbnail "input1" "thumbnail1" if-variable-matches="hello"
					thumbnail "input1" "thumbnail1" if-variable-matches="blah"
				}
				EOF
			end

			it 'should mark source to be included when variable value matches or when no value is expected is not empty' do
				subject.handlers[0].processors[0].excluded?(state).should be_false
				subject.handlers[0].processors[1].excluded?(state).should be_true
				subject.handlers[0].processors[2].excluded?(state).should be_false
				subject.handlers[0].processors[3].excluded?(state).should be_false
				subject.handlers[0].processors[4].excluded?(state).should be_true
			end

			context 'with multi thumbnail configuration form' do
				subject do
					Configuration.read(<<-'EOF')
					put {
						thumbnail "input1" if-variable-matches="hello:world" {
							"thumbnail3"
						}
						thumbnail "input2" if-variable-matches="hello:blah" {
							"thumbnail3"
						}
						thumbnail "input3" if-variable-matches="xyz" {
							"thumbnail4"
						}
						thumbnail "input4" if-variable-matches="hello:world" {
							"thumbnail5" if-variable-matches="hello:world"
						}
						thumbnail "input5" if-variable-matches="hello:world" {
							"thumbnail6" if-variable-matches="blah"
						}
					}
					EOF
				end

				it 'should mark source to be included when variable value matches or when no value is not empty' do
					subject.handlers[0].processors[0].excluded?(state).should be_false
					subject.handlers[0].processors[1].excluded?(state).should be_true
					subject.handlers[0].processors[2].excluded?(state).should be_false
					subject.handlers[0].processors[3].excluded?(state).should be_false
					subject.handlers[0].processors[4].excluded?(state).should be_false
				end
			end
		end
	end
end

