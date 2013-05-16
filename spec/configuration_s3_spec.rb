require_relative 'spec_helper'
require 'aws-sdk'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/s3'

describe Configuration do
	describe 's3' do
		subject do
			Configuration.read(<<-EOF)
			s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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"
			EOF
		end

		it 'should provide S3 key and secret' do
			subject.s3.key.should == 'AKIAJMUYVYOSACNXLPTQ'
			subject.s3.secret.should == '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'
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

	let :state do
		Configuration::RequestState.new('abc', :test_image => 'test.jpg')
	end

	describe Configuration::S3Source do
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
	end
end

