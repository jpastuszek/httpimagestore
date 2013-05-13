require_relative 'spec_helper'
require 'httpimagestore/configuration'
require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler'

require 'httpimagestore/configuration/thumbnailer'
require 'httpimagestore/configuration/s3'

describe Configuration do
	subject do
		Configuration.from_file('spec/full.cfg')
	end

	it 'should parse configuration file' do
		subject
	end

	describe 's3' do
		it 'should provide S3 key and secret' do
			subject.s3.key.should == 'AKIAJMUYVYOSACNXLPTQ'
			subject.s3.secret.should == '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'
		end
	end

	describe 'thumbnailer' do
		it 'should provide default URL' do
			subject.thumbnailer.url.should == 'http://localhost:3100'
		end

		it 'should allow to override default URL' do
			subject = Configuration.from_file('spec/full.cfg', thumbnailer_url: 'http://1.1.1.1:8080')
			subject.thumbnailer.url.should == 'http://1.1.1.1:8080'
		end

		it 'should get thumbnailer URL from configuration' do
			subject = Configuration.read('thumbnailer url="http://2.2.2.2:1000"')
			subject.thumbnailer.url.should == 'http://2.2.2.2:1000'
		end
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

	describe 'handler' do
		it 'should provide request matchers' do
			subject.handler[0].matchers.should == ['put', 'thumbnail', :name_list]
			subject.handler[1].matchers.should == ['post', 'original']
			subject.handler[2].matchers.should == ['get', 'thumbnail', 'v1', :operation, :width, :height, :options]
		end

		it 'should provide sources' do
			p subject.handler[0].image_source[0].render
			#p subject.handler[1].image_source
			#p subject.handler[2].image_source
		end
	end
end

