require_relative 'spec_helper'
require 'aws-sdk'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/s3'
MemoryLimit.logger = Logger.new('/dev/null')

unless ENV['AWS_ACCESS_KEY_ID'] and ENV['AWS_SECRET_ACCESS_KEY'] and ENV['AWS_S3_TEST_BUCKET']
	puts "AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY or AWS_S3_TEST_BUCKET environment variables not set - Skipping S3 specs"
else
	describe Configuration do
		describe Configuration::S3 do
			subject do
				Configuration.read(<<-EOF)
				s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
				EOF
			end

			it 'should provide S3 key and secret' do
				subject.s3.config.access_key_id.should == ENV['AWS_ACCESS_KEY_ID']
				subject.s3.config.secret_access_key.should == ENV['AWS_SECRET_ACCESS_KEY']
			end

			it 'should use SSL by default' do
				subject.s3.config.use_ssl.should be_true
			end

			it 'should allow disabling SSL' do
				subject = Configuration.read(<<-EOF)
				s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
				EOF

				subject.s3.config.use_ssl.should be_false
			end

			it 'should provide S3 client' do
				subject.s3.should be_a AWS::S3
			end

			describe 'error handling' do
				it 'should raise StatementCollisionError on duplicate s3 statement' do
					expect {
						Configuration.read(<<-EOF)
						s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
						s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
						EOF
					}.to raise_error Configuration::StatementCollisionError, %{syntax error while parsing 's3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"': only one s3 type statement can be specified within context}
				end

				it 'should raise NoAttributeError on missing key attribute' do
					expect {
						Configuration.read(<<-EOF)
						s3 secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 's3 secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"': expected 'key' attribute to be set}
				end

				it 'should raise NoAttributeError on missing secret attribute' do
					expect {
						Configuration.read(<<-EOF)
						s3 key="#{ENV['AWS_ACCESS_KEY_ID']}"
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 's3 key="#{ENV['AWS_ACCESS_KEY_ID']}"': expected 'secret' attribute to be set}
				end
			end
		end

		describe Configuration::S3Source do
			let :state do
				Configuration::RequestState.new('abc', {test_image: 'test.jpg'})
			end

			subject do
				Configuration.read(<<-EOF)
				s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
				path "hash" "\#{test_image}"
				get {
					source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
				}
				EOF
			end

			before :all do
				@test_data = (support_dir + 'compute.jpg').read.force_encoding('ASCII-8BIT')

				s3_client = AWS::S3.new(use_ssl: false)
				s3_test_bucket = s3_client.buckets[ENV['AWS_S3_TEST_BUCKET']]
				s3_test_bucket.objects['test.jpg'].write(@test_data, content_type: 'image/jpeg')
				s3_test_bucket.objects['test_prefix/test.jpg'].write(@test_data, content_type: 'image/jpeg')
			end

			it 'should source image from S3 using path spec' do
				subject.handlers[0].sources[0].should be_a Configuration::S3Source
				subject.handlers[0].sources[0].realize(state)

				state.images['original'].data.should == @test_data
			end

			it 'should use S3 object content type for mime type' do
				subject.handlers[0].sources[0].realize(state)

				state.images['original'].mime_type.should == 'image/jpeg'
			end

			it 'should provide source path and HTTPS url' do
				subject.handlers[0].sources[0].realize(state)

				state.images['original'].source_path.should == "test.jpg"
				state.images['original'].source_url.should start_with "https://"
				state.images['original'].source_url.should include ENV['AWS_S3_TEST_BUCKET']
				state.images['original'].source_url.should include "/test.jpg"
				state.images['original'].source_url.should include ENV['AWS_ACCESS_KEY_ID']
				status(state.images['original'].source_url).should == 200
			end

			describe 'storage prefix' do
				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
					path "hash" "\#{test_image}"
					get {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" prefix="test_prefix/"
					}
					EOF
				end

				it 'should still provide valid HTTPS URL incliding prefix' do
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].source_url.should start_with "https://"
					state.images['original'].source_url.should include ENV['AWS_S3_TEST_BUCKET']
					state.images['original'].source_url.should include "/test_prefix/test.jpg"
					state.images['original'].source_url.should include ENV['AWS_ACCESS_KEY_ID']
					status(state.images['original'].source_url).should == 200
				end

				it 'should provide source path without prefix' do
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].source_path.should == "test.jpg"
				end
			end

			describe 'non encrypted connection mode' do
				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					get {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
					}
					EOF
				end

				it 'should source image from S3 using path spec' do
					subject.handlers[0].sources[0].should be_a Configuration::S3Source
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].data.should == @test_data
				end

				it 'should provide source HTTP url' do
					subject.handlers[0].sources[0].realize(state)
					state.images['original'].source_url.should start_with "http://"
					state.images['original'].source_url.should include ENV['AWS_S3_TEST_BUCKET']
					state.images['original'].source_url.should include "/test.jpg"
					state.images['original'].source_url.should include ENV['AWS_ACCESS_KEY_ID']
					status(state.images['original'].source_url).should == 200
				end
			end

			describe 'context locals' do
				before :all do
					s3_client = AWS::S3.new(use_ssl: false)
					s3_test_bucket = s3_client.buckets[ENV['AWS_S3_TEST_BUCKET']]
					s3_test_bucket.objects['test-image-name.jpg'].write('hello world', content_type: 'image/jpeg')
					s3_test_bucket.objects["#{ENV['AWS_S3_TEST_BUCKET']}.jpg"].write('hello bucket', content_type: 'image/jpeg')
				end

				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "image_name" "\#{image_name}.jpg"
					path "bucket" "\#{bucket}.jpg"
					get {
						source_s3 "test-image-name" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="image_name"
						source_s3 "bucket" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="bucket"
					}
					EOF
				end

				it 'should provide image name to be used as #{image_name}' do
					subject.handlers[0].sources[0].realize(state)
					state.images['test-image-name'].source_path.should == 'test-image-name.jpg'
					state.images['test-image-name'].data.should == 'hello world'
				end

				it 'should provide bucket to be used as #{bucket}' do
					subject.handlers[0].sources[1].realize(state)
					state.images['bucket'].source_path.should == "#{ENV['AWS_S3_TEST_BUCKET']}.jpg"
					state.images['bucket'].data.should == 'hello bucket'
				end
			end

			describe 'error handling' do
				it 'should raise NoValueError on missing image name' do
					expect {
						Configuration.read(<<-EOF)
						get "test" {
							source_s3 bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
						}
						EOF
					}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'source_s3 bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"': expected image name}
				end

				it 'should raise NoAttributeError on missing bucket name' do
					expect {
						Configuration.read(<<-EOF)
						get "test" {
							source_s3 "original" path="hash"
						}
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_s3 "original" path="hash"': expected 'bucket' attribute to be set}
				end

				it 'should raise NoAttributeError on missing path' do
					expect {
						Configuration.read(<<-EOF)
						get "test" {
							source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}"
						}
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}"': expected 'path' attribute to be set}
				end

				it 'should raise S3NotConfiguredError if used but no s3 statement was used' do
					subject = Configuration.read(<<-'EOF')
					path "hash" "#{test_image}"
					get "test" {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].sources[0].realize(state)
					}.to raise_error Configuration::S3NotConfiguredError, 'S3 client not configured'
				end

				it 'should raise S3NoSuchBucketError if bucket was not found on S3' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					get "test" {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}X" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].sources[0].realize(state)
					}.to raise_error Configuration::S3NoSuchBucketError, %{S3 bucket '#{ENV['AWS_S3_TEST_BUCKET']}X' does not exist}
				end

				it 'should raise S3NoSuchKeyError if object was not found on S3' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "blah"
					get "test" {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].sources[0].realize(state)
					}.to raise_error Configuration::S3NoSuchKeyError, %{S3 bucket '#{ENV['AWS_S3_TEST_BUCKET']}' does not contain key 'blah'}
				end

				it 'should raise S3AccessDenied if bucket was not found on S3' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					get "test" {
						source_s3 "original" bucket="blah" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].sources[0].realize(state)
					}.to raise_error Configuration::S3AccessDenied, %{access to S3 bucket 'blah' or key 'test.jpg' was denied}
				end
			end

			describe 'memory limit' do
				let :state do
					Configuration::RequestState.new('abc', {test_image: 'test.jpg'}, '', {}, MemoryLimit.new(10))
				end

				it 'should raise MemoryLimit::MemoryLimitedExceededError when sourcing bigger image than limit' do
					expect {
						subject.handlers[0].sources[0].realize(state)
					}.to raise_error MemoryLimit::MemoryLimitedExceededError
				end
			end
		end

		describe Configuration::S3Store do
			let :state do
				Configuration::RequestState.new(@test_data, {test_image: 'test_out.jpg'})
			end

			subject do
				Configuration.read(<<-EOF)
				s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
				path "hash" "\#{test_image}"
				post {
					store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
				}
				EOF
			end

			before :all do
				@test_data = (support_dir + 'compute.jpg').read.force_encoding('ASCII-8BIT')

				s3_client = AWS::S3.new(use_ssl: false)
				s3_test_bucket = s3_client.buckets[ENV['AWS_S3_TEST_BUCKET']]
				@test_object = s3_test_bucket.objects['test_out.jpg']
				@test_object.delete
				test_object = s3_test_bucket.objects['test_prefix/test_out.jpg']
				test_object.delete
			end

			before :each do
				subject.handlers[0].sources[0].realize(state)
			end

			it 'should source image from S3 using path spec' do
				subject.handlers[0].stores[0].should be_a Configuration::S3Store
				subject.handlers[0].stores[0].realize(state)

				@test_object.read.should == @test_data
			end

			it 'should use image mime type as S3 object content type' do
				state.images['input'].mime_type = 'image/jpeg'
				subject.handlers[0].stores[0].realize(state)

				@test_object.head[:content_type].should == 'image/jpeg'
			end

			it 'should provide source path and HTTPS url' do
				subject.handlers[0].stores[0].realize(state)

				state.images['input'].store_path.should == "test_out.jpg"
				state.images['input'].store_url.should start_with "https://"
				state.images['input'].store_url.should include ENV['AWS_S3_TEST_BUCKET']
				state.images['input'].store_url.should include "/test_out.jpg"
				state.images['input'].store_url.should include ENV['AWS_ACCESS_KEY_ID']
				status(state.images['input'].store_url).should == 200
			end

			describe 'storage prefix' do
				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
					path "hash" "\#{test_image}"
					post {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" prefix="test_prefix/"
					}
					EOF
				end

				it 'should still provide valid HTTPS URL incliding prefix' do
					subject.handlers[0].stores[0].realize(state)

					state.images['input'].store_url.should start_with "https://"
					state.images['input'].store_url.should include ENV['AWS_S3_TEST_BUCKET']
					state.images['input'].store_url.should include "test_prefix/test_out.jpg"
					state.images['input'].store_url.should include ENV['AWS_ACCESS_KEY_ID']
					status(state.images['input'].store_url).should == 200
				end

				it 'should provide storage path without prefix' do
					subject.handlers[0].stores[0].realize(state)

					state.images['input'].store_path.should == "test_out.jpg"
				end
			end

			describe 'non encrypted connection mode' do
				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					post {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
					}
					EOF
				end

				it 'should source image from S3 using path spec' do
					subject.handlers[0].stores[0].should be_a Configuration::S3Store
					subject.handlers[0].stores[0].realize(state)

					@test_object.read.should == @test_data
				end

				it 'should provide source HTTP url' do
					subject.handlers[0].stores[0].realize(state)

					state.images['input'].store_url.should start_with "http://"
					state.images['input'].store_url.should include ENV['AWS_S3_TEST_BUCKET']
					state.images['input'].store_url.should include "/test_out.jpg"
					state.images['input'].store_url.should include ENV['AWS_ACCESS_KEY_ID']
					status(state.images['input'].store_url).should == 200
				end
			end

			describe 'permission control' do
				it 'should store images that are not accessible by public by default' do
					subject.handlers[0].stores[0].realize(state)
					status(state.images['input'].store_url[/^[^\?]*/]).should == 403
				end

				describe 'public' do
					subject do
						Configuration.read(<<-EOF)
						s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
						path "hash" "\#{test_image}"
						post {
							store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" public=true
						}
						EOF
					end

					it 'should store image accessible for public' do
						subject.handlers[0].stores[0].realize(state)

						get(state.images['input'].store_url).should == @test_data
					end

					it 'should provide public source HTTPS url' do
						subject.handlers[0].stores[0].realize(state)

						state.images['input'].store_url.should start_with "https://"
						state.images['input'].store_url.should include ENV['AWS_S3_TEST_BUCKET']
						state.images['input'].store_url.should include "/test_out.jpg"
						state.images['input'].store_url.should_not include ENV['AWS_ACCESS_KEY_ID']
						status(state.images['input'].store_url).should == 200
					end

					describe 'non encrypted connection mode' do
						subject do
							Configuration.read(<<-EOF)
							s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
							path "hash" "\#{test_image}"
							post {
								store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" public=true
							}
							EOF
						end

						it 'should provide public source HTTP url' do
							subject.handlers[0].stores[0].realize(state)

							state.images['input'].store_url.should start_with "http://"
							state.images['input'].store_url.should include ENV['AWS_S3_TEST_BUCKET']
							state.images['input'].store_url.should include "/test_out.jpg"
							state.images['input'].store_url.should_not include ENV['AWS_ACCESS_KEY_ID']
							status(state.images['input'].store_url).should == 200
						end
					end
				end
			end

			describe 'cache control' do
				it 'should have no cache control set by default' do
					subject.handlers[0].stores[0].realize(state)
					headers(state.images['input'].store_url)["Cache-Control"].should be_nil
				end

				describe 'set' do
					subject do
						Configuration.read(<<-EOF)
						s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
						path "hash" "\#{test_image}"
						post {
							store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" public=true cache-control="public, max-age=3600"
						}
						EOF
					end

					it 'should have given cahce control header set on the object' do
						subject.handlers[0].stores[0].realize(state)
						headers(state.images['input'].store_url)["Cache-Control"].should == 'public, max-age=3600'
					end
				end
			end

			describe 'conditional inclusion support' do
				let :state do
					Configuration::RequestState.new(@test_data, {test_image: 'test_out.jpg', list: 'input,input2'})
				end

				subject do
					Configuration.read(<<-EOF)
					post {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" if-image-name-on="\#{list}"
						store_s3 "input1" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" if-image-name-on="\#{list}"
						store_s3 "input2" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" if-image-name-on="\#{list}"
					}
					EOF
				end

				it 'should mark sores to be included when image name match if-image-name-on list' do
					subject.handlers[0].stores[0].excluded?(state).should be_false
					subject.handlers[0].stores[1].excluded?(state).should be_true
					subject.handlers[0].stores[2].excluded?(state).should be_false
				end
			end

			describe 'context locals' do
				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "image_name" "\#{image_name}"
					path "bucket" "\#{bucket}"
					path "image_mime_extension" "\#{image_mime_extension}"
					post {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="image_name"
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="bucket"
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="image_mime_extension"
					}
					EOF
				end

				it 'should provide image name to be used as #{image_name}' do
					subject.handlers[0].stores[0].realize(state)

					state.images['input'].store_path.should == 'input'
				end

				it 'should provide bucket to be used as #{bucket}' do
					subject.handlers[0].stores[1].realize(state)

					state.images['input'].store_path.should == ENV['AWS_S3_TEST_BUCKET']
				end

				it 'should provide image mime type based file extension to be used as #{image_mime_extension}' do
					state.images['input'].mime_type = 'image/jpeg'
					subject.handlers[0].stores[2].realize(state)

					state.images['input'].store_path.should == 'jpg'
				end

				it 'should raise NoValueForPathTemplatePlaceholerError if there is on mime type for image defined and path contains #{image_mime_extension}' do
					expect {
						subject.handlers[0].stores[2].realize(state)
					}.to raise_error Configuration::NoValueForPathTemplatePlaceholerError, %q{cannot generate path 'image_mime_extension' from template '#{image_mime_extension}': no value for '#{image_mime_extension}'}
				end
			end

			describe 'error handling' do
				it 'should raise NoValueError on missing image name' do
					expect {
						Configuration.read(<<-EOF)
						post "test" {
							store_s3 bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
						}
						EOF
					}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'store_s3 bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"': expected image name}
				end

				it 'should raise NoAttributeError on missing bucket name' do
					expect {
						Configuration.read(<<-EOF)
						post "test" {
							store_s3 "input" path="hash"
						}
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'store_s3 "input" path="hash"': expected 'bucket' attribute to be set}
				end

				it 'should raise NoAttributeError on missing path' do
					expect {
						Configuration.read(<<-EOF)
						post "test" {
							store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}"
						}
						EOF
					}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}"': expected 'path' attribute to be set}
				end

				it 'should raise S3NotConfiguredError if used but no s3 statement was used' do
					subject = Configuration.read(<<-EOF)
					path "hash" "\#{test_image}"
					post "test" {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].stores[0].realize(state)
					}.to raise_error Configuration::S3NotConfiguredError, 'S3 client not configured'
				end

				it 'should raise S3NoSuchBucketError if bucket was not found on S3' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					post "test" {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}X" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].stores[0].realize(state)
					}.to raise_error Configuration::S3NoSuchBucketError, %{S3 bucket '#{ENV['AWS_S3_TEST_BUCKET']}X' does not exist}
				end

				it 'should raise S3AccessDenied if bucket was not found on S3' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}" ssl=false
					path "hash" "\#{test_image}"
					post "test" {
						store_s3 "input" bucket="blah" path="hash"
					}
					EOF
					expect {
						subject.handlers[0].stores[0].realize(state)
					}.to raise_error Configuration::S3AccessDenied, %{access to S3 bucket 'blah' or key 'test_out.jpg' was denied}
				end
			end
		end
	end
end

