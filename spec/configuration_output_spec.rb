require_relative 'spec_helper'
require_relative 'support/cuba_response_env'

require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

require 'httpimagestore/configuration/output'
require 'httpimagestore/configuration/file'

describe Configuration do
	let :state do
		Configuration::RequestState.new('abc')
	end

	let :env do
		CubaResponseEnv.new
	end

	describe Configuration::OutputText do
		subject do
			Configuration.read(<<-'EOF')
			get "test" {
				output_text "hello world"
			}
			get "test" {
				output_text "bad stuff" status=500
			}
			get "test" {
				output_text "welcome" cache-control="public"
			}
			get "test" {
				output_text "test1: #{test1} test2: #{test2}"
			}
			EOF
		end

		it 'should output hello world with default 200 status' do
			subject.handlers[0].output.realize(state)
			env = CubaResponseEnv.new
			env.instance_eval &state.output_callback
			env.res.status.should == 200
			env.res.data.should == "hello world\r\n"
			env.res['Content-Type'].should == 'text/plain'
			env.res['Cache-Control'].should be_nil
		end

		it 'should output bad stuff with 500 status' do
			subject.handlers[1].output.realize(state)
			env = CubaResponseEnv.new
			env.instance_eval &state.output_callback
			env.res.status.should == 500
			env.res.data.should == "bad stuff\r\n"
			env.res['Content-Type'].should == 'text/plain'
			env.res['Cache-Control'].should be_nil
		end

		it 'should output welcome with public cache control' do
			subject.handlers[2].output.realize(state)
			env = CubaResponseEnv.new
			env.instance_eval &state.output_callback
			env.res.status.should == 200
			env.res.data.should == "welcome\r\n"
			env.res['Content-Type'].should == 'text/plain'
			env.res['Cache-Control'].should == 'public'
		end

		it 'should output text interpolated with variable values' do
			state = Configuration::RequestState.new
			state[:test1] = 'abc'
			state[:test2] = 'xyz'

			subject.handlers[3].output.realize(state)
			env = CubaResponseEnv.new
			env.instance_eval &state.output_callback
			env.res.data.should == "test1: abc test2: xyz\r\n"
		end
	end

	describe Configuration::OutputOK do
		subject do
			Configuration.read(<<-EOF)
			put "test" {
				output_ok
			}
			EOF
		end

		before :each do
			subject.handlers[0].sources[0].realize(state)
		end

		it 'should output 200 with OK text/plain message when realized' do
			state = Configuration::RequestState.new('abc')
			subject.handlers[0].output.realize(state)

			env = CubaResponseEnv.new
			env.instance_eval &state.output_callback
			env.res.status.should == 200
			env.res.data.should == "OK\r\n"
			env.res['Content-Type'].should == 'text/plain'
		end
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
			subject.handlers[0].sources[0].realize(state)
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

		describe 'Cache-Control header support' do
			subject do
				Configuration.read(<<-EOF)
				put "test" {
					output_image "input" cache-control="public, max-age=999, s-maxage=666"
				}
				EOF
			end

			it 'should allow setting Cache-Control header' do
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Cache-Control'].should == 'public, max-age=999, s-maxage=666'
			end
		end
	end

	describe 'output store paths and URLs' do
		let :utf_string do
			(support_dir + 'utf_string.txt').read.strip
		end

		let :in_file do
			Pathname.new("/tmp/test.in")
		end

		let :out_file do
			Pathname.new("/tmp/test.out")
		end

		let :out2_file do
			Pathname.new("/tmp/test.out2")
		end

		let :test_file do
			Pathname.new('/tmp/abc/test.out')
		end

		let :space_test_file do
			Pathname.new('/tmp/abc/t e s t.out')
		end

		let :utf_test_file do
			Pathname.new("/tmp/abc/#{utf_string}.out")
		end

		before :each do
			test_file.dirname.mkdir unless test_file.dirname.directory?
			test_file.open('w'){|io| io.write('abc')}
			space_test_file.open('w'){|io| io.write('abc')}
			in_file.open('w'){|io| io.write('abc')}
			out_file.unlink if out_file.exist?
			out2_file.unlink if out2_file.exist?
		end

		after :each do
			test_file.exist? and test_file.unlink
			space_test_file.exist? and space_test_file.unlink
			utf_test_file.exist? and utf_test_file.unlink
			test_file.dirname.exist? and test_file.dirname.rmdir
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

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "test.out\r\n"
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

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].sources[1].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].stores[1].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/plain'
				env.res.data.should == "test.out\r\ntest.out2\r\n"
			end

			describe 'conditional inclusion support' do
				let :state do
					Configuration::RequestState.new('abc', {list: 'input,image2'})
				end

				subject do
					Configuration.read(<<-'EOF')
					path {
						"in"		"test.in"
						"out1"	"test.out1"
						"out2"	"test.out2"
						"out3"	"test.out3"
					}

					post "multi" {
						source_file "image1" root="/tmp" path="in"
						source_file "image2" root="/tmp" path="in"

						store_file "input" root="/tmp" path="out1"
						store_file "image1" root="/tmp" path="out2"
						store_file "image2" root="/tmp" path="out3"

						output_store_path {
							"input"		if-image-name-on="#{list}"
							"image1"	if-image-name-on="#{list}"
							"image2"	if-image-name-on="#{list}"
						}
					}
					EOF
				end

				it 'should output store path only for images that names match if-image-name-on list' do
					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].sources[1].realize(state)
					subject.handlers[0].sources[2].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].stores[1].realize(state)
					subject.handlers[0].stores[2].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/plain'
					env.res.data.should == "test.out1\r\ntest.out3\r\n"
				end
			end

			describe 'custom formatting' do
				it 'should provide formatted file store path' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	"abc/test.out"
					path  "formatted"	"hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_path "input" path="formatted"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/plain'
					env.res.data.should == "hello/abc/world/test-xyz.out\r\n"
				end

				it 'should provide formatted file store path for each path' do
					subject = Configuration.read(<<-'EOF')
					path  "in"	  "test.in"
					path  "out"	  "abc/test.out"
					path  "out2"	"test.out2"

					path  "formatted"	  "hello/#{dirname}/world/#{basename}-xyz.#{extension}"
					path  "formatted2"	"#{image_digest}.#{extension}"

					post "single" {
						source_file "original" root="/tmp" path="in"

						store_file "input" root="/tmp" path="out"
						store_file "original" root="/tmp" path="out2"

						output_store_path {
							"input" path="formatted"
							"original" path="formatted2"
						}
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].sources[1].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].stores[1].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/plain'
					env.res.data.should == "hello/abc/world/test-xyz.out\r\nba7816bf8f01cfea.out2\r\n"
				end
			end

			describe 'error handling' do
				it 'should raise StorePathNotSetForImage for output of not stored image' do
					subject = Configuration.read(<<-EOF)
					post "single" {
						output_store_path "input"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)

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

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/uri-list'
				env.res.data.should == "file:/test.out\r\n"
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

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].sources[1].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].stores[1].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/uri-list'
				env.res.data.should == "file:/test.out\r\nfile:/test.out2\r\n"
			end

			describe 'conditional inclusion support' do
				let :state do
					Configuration::RequestState.new('abc', list: 'input,image2')
				end

				subject do
					Configuration.read(<<-'EOF')
					path {
						"in"		"test.in"
						"out1"	"test.out1"
						"out2"	"test.out2"
						"out3"	"test.out3"
					}

					post "multi" {
						source_file "image1" root="/tmp" path="in"
						source_file "image2" root="/tmp" path="in"

						store_file "input" root="/tmp" path="out1"
						store_file "image1" root="/tmp" path="out2"
						store_file "image2" root="/tmp" path="out3"

						output_store_url {
							"input"		if-image-name-on="#{list}"
							"image1"	if-image-name-on="#{list}"
							"image2"	if-image-name-on="#{list}"
						}
					}
					EOF
				end

				it 'should output store url only for images that names match if-image-name-on list' do
					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].sources[1].realize(state)
					subject.handlers[0].sources[2].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].stores[1].realize(state)
					subject.handlers[0].stores[2].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "file:/test.out1\r\nfile:/test.out3\r\n"
				end
			end

			describe 'URL rewrites' do
				it 'should allow using path spec to rewrite URL path component' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"

					path  "formatted"	  "hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url "input" path="formatted"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "file:/hello/abc/world/test-xyz.out\r\n"
				end

				it 'should allow rewriting scheme component' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url "input" scheme="ftp"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "ftp:/abc/test.out\r\n"
				end

				it 'should allow rewriting host component' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url "input" host="localhost"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "file://localhost/abc/test.out\r\n"
				end

				it 'should allow rewriting port component (defaults host to localhost)' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url "input" port="21"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "file://localhost:21/abc/test.out\r\n"
				end

				it 'should allow using variables for all supported rewrites' do
					state = Configuration::RequestState.new('abc',
						remote: 'example.com',
						remote_port: 421,
						proto: 'ftp'
					)
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"
					path  "formatted"	  "hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url "input" scheme="#{proto}" host="#{remote}" port="#{remote_port}" path="formatted"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "ftp://example.com:421/hello/abc/world/test-xyz.out\r\n"
				end
			end

			describe 'URL encoding' do
				it 'should provide properly encoded file store URL' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/t e s t.out"
					path  "formatted"	  "hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_url {
							"input"
							"input" path="formatted"
						}
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "file:/abc/t%20e%20s%20t.out\r\nfile:/hello/abc/world/t%20e%20s%20t-xyz.out\r\n"
				end
			end

			describe 'error handling' do
				it 'should raise StoreURLNotSetForImage for output of not stored image' do
					subject = Configuration.read(<<-EOF)
					post "single" {
						output_store_url "input"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)

					expect {
						subject.handlers[0].output.realize(state)
					}.to raise_error Configuration::StoreURLNotSetForImage, %{store URL not set for image 'input'}
				end
			end
		end

		describe Configuration::OutputStoreURI do
			it 'should provide file store URI' do
				subject = Configuration.read(<<-EOF)
				path {
					"out"	"test.out"
				}

				post "single" {
					store_file "input" root="/tmp" path="out"

					output_store_uri "input"
				}
				EOF

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/uri-list'
				env.res.data.should == "/test.out\r\n"
			end

			it 'should provide multiple file store URIs' do
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

					output_store_uri {
						"input"
						"original"
					}
				}
				EOF

				subject.handlers[0].sources[0].realize(state)
				subject.handlers[0].sources[1].realize(state)
				subject.handlers[0].stores[0].realize(state)
				subject.handlers[0].stores[1].realize(state)
				subject.handlers[0].output.realize(state)

				env.instance_eval &state.output_callback
				env.res['Content-Type'].should == 'text/uri-list'
				env.res.data.should == "/test.out\r\n/test.out2\r\n"
			end

			describe 'conditional inclusion support' do
				let :state do
					Configuration::RequestState.new('abc', list: 'input,image2')
				end

				subject do
					Configuration.read(<<-'EOF')
					path {
						"in"		"test.in"
						"out1"	"test.out1"
						"out2"	"test.out2"
						"out3"	"test.out3"
					}

					post "multi" {
						source_file "image1" root="/tmp" path="in"
						source_file "image2" root="/tmp" path="in"

						store_file "input" root="/tmp" path="out1"
						store_file "image1" root="/tmp" path="out2"
						store_file "image2" root="/tmp" path="out3"

						output_store_uri {
							"input"		if-image-name-on="#{list}"
							"image1"	if-image-name-on="#{list}"
							"image2"	if-image-name-on="#{list}"
						}
					}
					EOF
				end

				it 'should output store url only for images that names match if-image-name-on list' do
					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].sources[1].realize(state)
					subject.handlers[0].sources[2].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].stores[1].realize(state)
					subject.handlers[0].stores[2].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "/test.out1\r\n/test.out3\r\n"
				end
			end

			describe 'URI rewrites' do
				it 'should allow using path spec to rewrite URI path' do
					subject = Configuration.read(<<-'EOF')
					path  "out"	  "abc/test.out"

					path  "formatted"	  "hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_uri "input" path="formatted"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "/hello/abc/world/test-xyz.out\r\n"
				end
			end

			describe 'URI encoding' do
				let :subject do
					Configuration.read(<<-'EOF')
					path  "out"         "abc/#{name}.out"
					path  "formatted"   "hello/#{dirname}/world/#{basename}-xyz.#{extension}"

					post "single" {
						store_file "input" root="/tmp" path="out"

						output_store_uri {
							"input"
							"input" path="formatted"
						}
					}
					EOF
				end

				it 'should provide properly encoded file store URI' do
					state = Configuration::RequestState.new('abc', name: 't e s t')

					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					env.res.data.should == "/abc/t%20e%20s%20t.out\r\n/hello/abc/world/t%20e%20s%20t-xyz.out\r\n"
				end

				it 'should handle UTF-8 characters' do
					state = Configuration::RequestState.new('abc', name: utf_string)
					subject.handlers[0].sources[0].realize(state)
					subject.handlers[0].stores[0].realize(state)
					subject.handlers[0].output.realize(state)

					env.instance_eval &state.output_callback
					env.res['Content-Type'].should == 'text/uri-list'
					l1, l2 = *env.res.data.split("\r\n")
					URI.utf_decode(l1).should == "/abc/#{utf_string}.out"
					URI.utf_decode(l2).should == "/hello/abc/world/#{utf_string}-xyz.out"
				end
			end

			describe 'error handling' do
				it 'should raise StoreURLNotSetForImage for output of not stored image' do
					subject = Configuration.read(<<-EOF)
					post "single" {
						output_store_uri "input"
					}
					EOF

					subject.handlers[0].sources[0].realize(state)

					expect {
						subject.handlers[0].output.realize(state)
					}.to raise_error Configuration::StoreURLNotSetForImage, %{store URL not set for image 'input'}
				end
			end
		end
	end
end
