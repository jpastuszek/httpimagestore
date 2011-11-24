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
end

