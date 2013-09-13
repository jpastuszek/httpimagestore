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

		describe Configuration::S3SourceStoreBase::CacheRoot do
			subject do
				Configuration::S3SourceStoreBase::CacheRoot.new('/tmp')
			end

			before do
				@cache_file = Pathname.new('/tmp/0d/bf/50c256d6b6efe55d11d0b6b50600')
				@cache_file.dirname.mkpath
				@cache_file.open('w') do |io|
					io.write 'abc'
				end

				test2 = Pathname.new('/tmp/46/b9/7a454d831d7570abbb833330d9fb')
				test2.unlink if test2.exist?
			end

			it 'should build cache file location for storage location from bucket and key' do
				cache_file = subject.cache_file('mybucket', 'hello/world.jpg')
				cache_file.should be_a Configuration::S3SourceStoreBase::CacheRoot::CacheFile
				cache_file.to_s.should == "/tmp/0d/bf/50c256d6b6efe55d11d0b6b50600"
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

			describe 'object cache' do
				let :state do
					Configuration::RequestState.new('abc', {test_image: 'test/ghost.jpg'})
				end

				subject do
					Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
					path "hash" "\#{test_image}"
					get {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp"
						source_s3 "original_cached" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp"
						source_s3 "original_cached_public" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp" public="true"
						source_s3 "original_cached_public2" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp" public="true"
					}

					post {
						store_s3 "input" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp"
					}
					EOF
				end

				before do
					@cache_file = Pathname.new('/tmp/ce/26/b196585e28aa99f55b1260b629e2')
					@cache_file.dirname.mkpath
					@cache_file.open('wb') do |io|
						header = MessagePack.pack(
							'private_url' => 'https://s3-eu-west-1.amazonaws.com/test/ghost.jpg?' + ENV['AWS_ACCESS_KEY_ID'],
							'public_url' => 'https://s3-eu-west-1.amazonaws.com/test/ghost.jpg',
							'content_type' => 'image/jpeg'
						)
						io.write [header.length].pack('L') # header length
						io.write header
						io.write 'abc'
					end
				end

				it 'should use cache when configured and object in cache' do
					subject.handlers[0].sources[0].should be_a Configuration::S3Source
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].data.should == 'abc'
				end

				it 'should keep mime type' do
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].mime_type.should == 'image/jpeg'
				end

				it 'should keep private source URL' do
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].source_url.should == 'https://s3-eu-west-1.amazonaws.com/test/ghost.jpg?' + ENV['AWS_ACCESS_KEY_ID']
				end

				it 'should keep public source URL' do
					subject = Configuration.read(<<-EOF)
					s3 key="#{ENV['AWS_ACCESS_KEY_ID']}" secret="#{ENV['AWS_SECRET_ACCESS_KEY']}"
					path "hash" "\#{test_image}"
					get {
						source_s3 "original" bucket="#{ENV['AWS_S3_TEST_BUCKET']}" path="hash" cache-root="/tmp" public=true
					}
					EOF
					subject.handlers[0].sources[0].realize(state)

					state.images['original'].source_url.should == 'https://s3-eu-west-1.amazonaws.com/test/ghost.jpg'
				end

				describe 'read-through' do
					it 'shluld use object stored in S3 when not found in the cache' do
						cache_file = Pathname.new('/tmp/af/a3/5eaf0a614693e2d1ed455ac1cedb')
						cache_file.unlink if cache_file.exist?

						state = Configuration::RequestState.new('abc', {test_image: 'test.jpg'})
						subject.handlers[0].sources[0].realize(state)

						cache_file.should exist
					end

					it 'should write cache on read and be able to use it on next read' do
						cache_file = Pathname.new('/tmp/af/a3/5eaf0a614693e2d1ed455ac1cedb')
						cache_file.unlink if cache_file.exist?

						state = Configuration::RequestState.new('abc', {test_image: 'test.jpg'})
						subject.handlers[0].sources[0].realize(state)

						cache_file.should exist

						subject.handlers[0].sources[1].realize(state)

						state.images['original'].data.should == @test_data
						state.images['original'].mime_type.should == 'image/jpeg'

						state.images['original_cached'].data.should == @test_data
						state.images['original_cached'].mime_type.should == 'image/jpeg'
					end

					it 'should update cached object with new properties read from S3' do
						cache_file = Pathname.new('/tmp/af/a3/5eaf0a614693e2d1ed455ac1cedb')
						cache_file.unlink if cache_file.exist?

						state = Configuration::RequestState.new('abc', {test_image: 'test.jpg'})

						## cache with private URL
						subject.handlers[0].sources[0].realize(state)

						cache_file.should exist
						sum = Digest::SHA2.new.update(cache_file.read).to_s

						## read from cache with private URL
						subject.handlers[0].sources[1].realize(state)

						# no change
						Digest::SHA2.new.update(cache_file.read).to_s.should == sum

						## read from cache; add public URL
						subject.handlers[0].sources[2].realize(state)

						# should get updated
						Digest::SHA2.new.update(cache_file.read).to_s.should_not == sum
						
						sum = Digest::SHA2.new.update(cache_file.read).to_s
						## read from cahce
						subject.handlers[0].sources[3].realize(state)

						# no change
						Digest::SHA2.new.update(cache_file.read).to_s.should == sum
					end

					describe 'error handling' do
						let :state do
							Configuration::RequestState.new('abc', {test_image: 'test.jpg'})
						end
						
						before :each do
							@cache_file = Pathname.new('/tmp/af/a3/5eaf0a614693e2d1ed455ac1cedb')
							@cache_file.dirname.mkpath
							@cache_file.open('wb') do |io|
								header = 'xyz'
								io.write [header.length].pack('L') # header length
								io.write header
								io.write 'abc'
							end
						end

						it 'should rewrite cached object when corrupted' do
							subject.handlers[0].sources[0].realize(state)
							state.images['original'].data.should == @test_data

							cache = @cache_file.read.force_encoding('ASCII-8BIT')
							cache.should_not include 'xyz'
							cache.should include @test_data
						end

						it 'should use S3 object when cache file is not accessible' do
							@cache_file.chmod(0000)
							begin
								subject.handlers[0].sources[0].realize(state)
								state.images['original'].data.should == @test_data
							ensure
								@cache_file.chmod(0644)

								cache = @cache_file.read.force_encoding('ASCII-8BIT')
								cache.should include 'xyz'
								cache.should_not include @test_data
							end
						end

						it 'should use S3 object when cache direcotry is not accessible' do
							@cache_file.dirname.chmod(0000)
							begin
								subject.handlers[0].sources[0].realize(state)
								state.images['original'].data.should == @test_data
							ensure
								@cache_file.dirname.chmod(0755)

								cache = @cache_file.read.force_encoding('ASCII-8BIT')
								cache.should include 'xyz'
								cache.should_not include @test_data
							end
						end

						it 'should not store cache file for S3 objects that does not exist' do
							cache_file = Pathname.new('/tmp/a2/fd/4261e9a7586ed772d0c78bb51c9d')
							cache_file.unlink if cache_file.exist?

							state = Configuration::RequestState.new('abc', {test_image: 'bogous.jpg'})

							expect {
								subject.handlers[0].sources[0].realize(state)
							}.to raise_error Configuration::S3NoSuchKeyError

							cache_file.should_not exist
						end
					end
				end

				describe 'write-through' do
					let :state do
						Configuration::RequestState.new(@test_data, {test_image: 'test_cache.jpg'})
					end

					before :each do
					end

					it 'should cache S3 object during write' do
						cache_file = Pathname.new('/tmp/31/f6/d48147b9981bb880fb1861539e3f')
						cache_file.unlink if cache_file.exist?

						subject.handlers[1].sources[0].realize(state)
						state.images['input'].mime_type = 'image/jpeg'
						subject.handlers[1].stores[0].realize(state)

						# we have cache
						cache_file.should exist

						# but delete S3 so it will fail if cache was not used fully
						s3_client = AWS::S3.new(use_ssl: false)
						s3_test_bucket = s3_client.buckets[ENV['AWS_S3_TEST_BUCKET']]
						s3_test_bucket.objects['test_cache.jpg'].delete

						state = Configuration::RequestState.new('', {test_image: 'test_cache.jpg'})
						expect {
							subject.handlers[0].sources[0].realize(state)
						}.not_to raise_error
							state.images['original'].data.should == @test_data
					end
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

				it 'should raise PathRenderingError if there is on mime type for image defined and path contains #{image_mime_extension}' do
					expect {
						subject.handlers[0].stores[2].realize(state)
					}.to raise_error Configuration::PathRenderingError, %q{cannot generate path 'image_mime_extension' from template '#{image_mime_extension}': image 'input' does not have data for variable 'image_mime_extension'}
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

