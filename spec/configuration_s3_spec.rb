require_relative 'spec_helper'
require 'httpimagestore/configuration'
Configuration::Scope.logger = Logger.new('/dev/null')

require 'httpimagestore/configuration/s3'

describe Configuration do

	describe 's3' do
		subject do
			Configuration.from_file(support_dir + 's3.cfg')
		end

		it 'should provide S3 key and secret' do
			subject.s3.key.should == 'AKIAJMUYVYOSACNXLPTQ'
			subject.s3.secret.should == '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'
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
end

