require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpimagestore/pathname'

describe Pathname do
	describe "#original_image" do
		it "returns path with tid" do
			Pathname.new("test/file/path.jpg").original_image(123).to_s.should == "test/file/123/path.jpg"
		end
	end

	describe "#thumbnail_image" do
		it "returns path with tid and thumbnail class name in file name" do
			Pathname.new("test/file/path.jpg").thumbnail_image(123, 'small').to_s.should == "test/file/123/path-small.jpg"
		end
	end
end
 
