require_relative 'spec_helper'
require 'httpimagestore/configuration'
require 'httpimagestore/configuration/s3'

describe Configuration do
	subject do
		Configuration.from_file(support_dir + 's3.cfg')
	end

	describe 's3' do
		it 'should provide S3 key and secret' do
			subject.s3.key.should == 'AKIAJMUYVYOSACNXLPTQ'
			subject.s3.secret.should == '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'
		end
	end
end

