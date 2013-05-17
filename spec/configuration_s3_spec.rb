require_relative 'spec_helper'
require 'aws-sdk'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/s3'

describe Configuration do
	describe Configuration::S3 do
		subject do
			Configuration.read(<<-EOF)
			s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
			EOF
		end

		it 'should provide S3 key and secret' do
			subject.s3.key.should == 'AKIAJMUYVYOSACNXLPTQ'
			subject.s3.secret.should == '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'
		end

		it 'should use SSL by default' do
			subject.s3.ssl.should be_true
		end

		it 'should allow disabling SSL' do
			subject = Configuration.read(<<-EOF)
			s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
			EOF

			subject.s3.ssl.should be_false
		end

		it 'should provide S3 client' do
			subject.s3.client.should be_a AWS::S3
		end

		describe 'error handling' do
			it 'should raise StatementCollisionError on duplicate s3 statement' do
				expect {
					Configuration.read(<<-EOF)
					s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
					s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
					EOF
				}.to raise_error Configuration::StatementCollisionError, %{syntax error while parsing 's3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"': only one s3 type statement can be specified within context}
			end

			it 'should raise NoAttributeError on missing key attribute' do
				expect {
					Configuration.read(<<-EOF)
					s3 secret="MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y"
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 's3 secret="MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y"': expected 'key' attribute to be set}
			end

			it 'should raise NoAttributeError on missing secret attribute' do
				expect {
					Configuration.read(<<-EOF)
					s3 key="AKIAJMUYVYOSACNXLPTQ"
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 's3 key="AKIAJMUYVYOSACNXLPTQ"': expected 'secret' attribute to be set}
			end
		end
	end

	describe Configuration::S3Source do
		let :state do
			Configuration::RequestState.new('abc', :test_image => 'test.jpg')
		end

		subject do
			Configuration.read(<<-'EOF')
			s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
			path "hash" "#{test_image}"
			get {
				source_s3 "original" bucket="httpimagestoretest" path="hash"
			}
			EOF
		end

		before :all do
			@test_data = (support_dir + 'compute.jpg').read.force_encoding('ASCII-8BIT')

			s3_client = AWS::S3.new(
				access_key_id: 'AKIAJMUYVYOSACNXLPTQ', 
				secret_access_key: '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',
				use_ssl: false
			)
			s3_test_bucket = s3_client.buckets['httpimagestoretest']
			s3_test_bucket.objects['test.jpg'].write(@test_data, content_type: 'image/jpeg')
			#p s3_test_bucket.objects['test.jpg'].read.length
		end

		it 'should source image from S3 using path spec' do
			subject.handlers[0].image_sources[0].should be_a Configuration::S3Source
			subject.handlers[0].image_sources[0].realize(state)

			state.images['original'].data.should == @test_data
		end

		it 'should use S3 object content type for mime type' do
			subject.handlers[0].image_sources[0].realize(state)

			state.images['original'].mime_type.should == 'image/jpeg'
		end

		it 'should provide source path and HTTPS url' do
			subject.handlers[0].image_sources[0].realize(state)

			state.images['original'].source_path.should == "test.jpg"
			state.images['original'].source_url.should start_with 'https://httpimagestoretest.s3.amazonaws.com/test.jpg?AWSAccessKeyId=AKIAJMUYVYOSACNXLPTQ&'
		end

		describe 'non encrypted connection mode' do
			subject do
				Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
				get {
					source_s3 "original" bucket="httpimagestoretest" path="hash"
				}
				EOF
			end

			it 'should source image from S3 using path spec' do
				subject.handlers[0].image_sources[0].should be_a Configuration::S3Source
				subject.handlers[0].image_sources[0].realize(state)

				state.images['original'].data.should == @test_data
			end

			it 'should provide source HTTP url' do
				subject.handlers[0].image_sources[0].realize(state)

				state.images['original'].source_path.should == "test.jpg"
				state.images['original'].source_url.should start_with 'http://httpimagestoretest.s3.amazonaws.com/test.jpg?AWSAccessKeyId=AKIAJMUYVYOSACNXLPTQ&'
			end
		end

		describe 'error handling' do
			it 'should raise NoValueError on missing image name' do
				expect {
					Configuration.read(<<-EOF)
					get "test" {
						source_s3 bucket="httpimagestoretest" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'source_s3 bucket="httpimagestoretest" path="hash"': expected image name}
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
						source_s3 "original" bucket="httpimagestoretest"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'source_s3 "original" bucket="httpimagestoretest"': expected 'path' attribute to be set}
			end

			it 'should raise S3NotConfiguredError if used but no s3 statement was used' do
				subject = Configuration.read(<<-'EOF')
				path "hash" "#{test_image}"
				get "test" {
					source_s3 "original" bucket="httpimagestoretest" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].image_sources[0].realize(state)
				}.to raise_error Configuration::S3NotConfiguredError, 'S3 client not configured'
			end

			it 'should raise S3NoSuchBucketError if bucket was not found on S3' do
				subject = Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
				get "test" {
					source_s3 "original" bucket="httpimagestoretestX" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].image_sources[0].realize(state)
				}.to raise_error Configuration::S3NoSuchBucketError, %{S3 bucket 'httpimagestoretestX' does not exist}
			end

			it 'should raise S3NoSuchKeyError if object was not found on S3' do
				subject = Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "blah"
				get "test" {
					source_s3 "original" bucket="httpimagestoretest" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].image_sources[0].realize(state)
				}.to raise_error Configuration::S3NoSuchKeyError, %{S3 bucket 'httpimagestoretest' does not contain key 'blah'}
			end

			it 'should raise S3AccessDenied if bucket was not found on S3' do
				subject = Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
				get "test" {
					source_s3 "original" bucket="blah" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].image_sources[0].realize(state)
				}.to raise_error Configuration::S3AccessDenied, %{access to S3 bucket 'blah' or key 'test.jpg' was denied}
			end
		end
	end

	describe Configuration::S3Store do
		let :state do
			Configuration::RequestState.new(@test_data, :test_image => 'test_out.jpg')
		end

		subject do
			Configuration.read(<<-'EOF')
			s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
			path "hash" "#{test_image}"
			post {
				store_s3 "input" bucket="httpimagestoretest" path="hash"
			}
			EOF
		end

		before :all do
			@test_data = (support_dir + 'compute.jpg').read.force_encoding('ASCII-8BIT')

			s3_client = AWS::S3.new(
				access_key_id: 'AKIAJMUYVYOSACNXLPTQ', 
				secret_access_key: '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',
				use_ssl: false
			)
			s3_test_bucket = s3_client.buckets['httpimagestoretest']
			@test_object = s3_test_bucket.objects['test_out.jpg']
			@test_object.delete
		end

		before :each do
			subject.handlers[0].image_sources[0].realize(state)
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
			state.images['input'].store_url.should start_with 'https://httpimagestoretest.s3.amazonaws.com/test_out.jpg?AWSAccessKeyId=AKIAJMUYVYOSACNXLPTQ&'
		end

		describe 'non encrypted connection mode' do
			subject do
				Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
				post {
					store_s3 "input" bucket="httpimagestoretest" path="hash"
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

				state.images['input'].store_path.should == "test_out.jpg"
				state.images['input'].store_url.should start_with 'http://httpimagestoretest.s3.amazonaws.com/test_out.jpg?AWSAccessKeyId=AKIAJMUYVYOSACNXLPTQ&'
			end
		end

		describe 'error handling' do
			it 'should raise NoValueError on missing image name' do
				expect {
					Configuration.read(<<-EOF)
					post "test" {
						store_s3 bucket="httpimagestoretest" path="hash"
					}
					EOF
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'store_s3 bucket="httpimagestoretest" path="hash"': expected image name}
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
						store_s3 "input" bucket="httpimagestoretest"
					}
					EOF
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'store_s3 "input" bucket="httpimagestoretest"': expected 'path' attribute to be set}
			end

			it 'should raise S3NotConfiguredError if used but no s3 statement was used' do
				subject = Configuration.read(<<-'EOF')
				path "hash" "#{test_image}"
				post "test" {
					store_s3 "input" bucket="httpimagestoretest" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].stores[0].realize(state)
				}.to raise_error Configuration::S3NotConfiguredError, 'S3 client not configured'
			end

			it 'should raise S3NoSuchBucketError if bucket was not found on S3' do
				subject = Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
				post "test" {
					store_s3 "input" bucket="httpimagestoretestX" path="hash"
				}
				EOF
				expect {
					subject.handlers[0].stores[0].realize(state)
				}.to raise_error Configuration::S3NoSuchBucketError, %{S3 bucket 'httpimagestoretestX' does not exist}
			end

			it 'should raise S3AccessDenied if bucket was not found on S3' do
				subject = Configuration.read(<<-'EOF')
				s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false
				path "hash" "#{test_image}"
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

