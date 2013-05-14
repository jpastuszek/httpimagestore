require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	subject do
		Configuration.from_file(support_dir + 'path.cfg')
	end

	describe 'path specs' do
		it 'should load path and render spec templates' do
			subject.paths['uri'].render(path: 'test/abc.jpg').should == 'test/abc.jpg'
			subject.paths['hash'].render(path: 'test/abc.jpg', image_data: 'hello').should == '2cf24dba5fb0a30e.jpg'
			subject.paths['hash-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == '2cf24dba5fb0a30e/xbrna.jpg'
			subject.paths['structured'].render(path: 'test/abc.jpg', image_data: 'hello').should == 'test/2cf24dba5fb0a30e/abc.jpg'
			subject.paths['structured-name'].render(path: 'test/abc.jpg', image_data: 'hello', imagename: 'xbrna').should == 'test/2cf24dba5fb0a30e/abc-xbrna.jpg'
		end
	end
end

