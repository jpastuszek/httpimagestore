require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpimagestore/configuration'

describe Configuration do
	it "should provide thumbnail classes" do
		c = Configuration.new do
			thumbnail_class 'small', 'crop', 128, 128, 'JPEG', :magick => 'option', :number => 42
			thumbnail_class 'tiny', 'pad', 32, 48, 'PNG'
			thumbnail_class 'test', 'pad', 32, 48
		end.get

		tc = c.thumbnail_classes['small']
		tc.name.should == 'small'
		tc.method.should == 'crop'
		tc.width.should == 128
		tc.height.should == 128
		tc.format.should == 'JPEG'
		tc.options.should == { :magick => 'option', :number => 42}

		tc = c.thumbnail_classes['tiny']
		tc.name.should == 'tiny'
		tc.method.should == 'pad'
		tc.width.should == 32
		tc.height.should == 48
		tc.format.should == 'PNG'
		tc.options.should == {}

		tc = c.thumbnail_classes['test']
		tc.name.should == 'test'
		tc.method.should == 'pad'
		tc.width.should == 32
		tc.height.should == 48
		tc.format.should == 'JPEG'
		tc.options.should == {}
	end

	it "should provide S3 key id and secret" do
		c = Configuration.new do
			s3_key 'abc', 'xyz'
		end.get

		c.s3_key_id.should == 'abc'
		c.s3_key_secret.should == 'xyz'
	end

	it "should provide S3 bucket" do
		c = Configuration.new do
			s3_bucket 'test'
		end.get

		c.s3_bucket.should == 'test'
	end

	it "should provide thumbnailer_url defaulting to http://localhost:3100" do
		c = Configuration.new do
		end.get

		c.thumbnailer_url.should == 'http://localhost:3100'

		c = Configuration.new do
			thumbnailer_url 'http://test'
		end.get

		c.thumbnailer_url.should == 'http://test'
	end
end

