require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpimagestore/plugin/image_path'
require 'pathname'

shared_examples "extension handling" do |image_path|
	describe "#original_image" do
		it "determines extension based on mime type" do
			Pathname.new(image_path.original_image("image/jpeg")).extname.should == ".jpg"
			Pathname.new(image_path.original_image("image/tiff")).extname.should == ".tif"
			Pathname.new(image_path.original_image("image/png")).extname.should == ".png"
		end

		it "should fail if provided extension from mime type could not be determined" do
			lambda {
				image_path.original_image("image/xyz")
			}.should raise_error Plugin::ImagePath::CouldNotDetermineFileExtensionError, "could not determine file extension for mime type: image/xyz"
		end
	end

	describe "#thumbnail_image" do
		it "determines extension based on mime type" do
			Pathname.new(image_path.thumbnail_image("image/jpeg", "small")).extname.should == ".jpg"
			Pathname.new(image_path.thumbnail_image("image/tiff", "small")).extname.should == ".tif"
			Pathname.new(image_path.thumbnail_image("image/png", "small")).extname.should == ".png"
		end

		it "should fail if provided extension from mime type could not be determined" do
			lambda {
				image_path.thumbnail_image("image/xyz", "small")
			}.should raise_error Plugin::ImagePath::CouldNotDetermineFileExtensionError, "could not determine file extension for mime type: image/xyz"
		end
	end
end

describe Plugin::ImagePath do
	describe Plugin::ImagePath::Auto do
		describe "#original_image" do
			it "returns path in format <id>.<ext>" do
				Plugin::ImagePath::Auto.new(123).original_image("image/jpeg").should == "123.jpg"
			end
		end

		describe "#thumbnail_image" do
			it "returns path in format <id>/<class>.<ext>" do
				Plugin::ImagePath::Auto.new(123).thumbnail_image("image/jpeg", "small").should == "123/small.jpg"
			end
		end

		include_examples "extension handling", Plugin::ImagePath::Auto.new(123)
	end

	describe Plugin::ImagePath::Custom do
		describe "#original_image" do
			it "returns path in format abc/<id>/xyz.<ext>" do
				Plugin::ImagePath::Custom.new(123, "test/file/path.jpg").original_image("image/jpeg").should == "test/file/123/path.jpg"
			end

			it "should fail back to provided extension if extension from mime type could not be determined" do
				Pathname.new(Plugin::ImagePath::Custom.new(123, "test/file/path.abc").original_image("image/xyz")).extname.should == ".abc"
			end
		end

		describe "#thumbnail_image" do
			it "returns path in format abc/<id>/xyz-<class>.<ext>" do
				Plugin::ImagePath::Custom.new(123, "test/file/path.jpg").thumbnail_image("image/jpeg", "small").should == "test/file/123/path-small.jpg"
			end
		end

		include_examples "extension handling", Plugin::ImagePath::Custom.new(123, "test/file/path")
	end
end
 
