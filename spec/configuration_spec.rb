require_relative 'spec_helper'
require 'httpimagestore/configuration'

Configuration::Scope.logger = Logger.new('/dev/null')

require 'pathname'
Pathname.glob('lib/httpimagestore/configuration/*.rb').each do |conf|
	require conf.relative_path_from(Pathname.new 'lib').to_s
end

describe Configuration do
	it 'should parse configuration file' do
		Configuration.from_file(support_dir + 'full.cfg')
	end

	it 'should read configuration from string' do
		Configuration.read (support_dir + 'full.cfg').read
	end
end

