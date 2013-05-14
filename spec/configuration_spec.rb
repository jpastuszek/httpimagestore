require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	it 'should parse configuration file' do
		Configuration.from_file(support_dir + 'full.cfg')
	end

	it 'should read configuration from string' do
		Configuration.read(<<EOF)
path {
	"uri" "blah"
}
EOF
	end
end

