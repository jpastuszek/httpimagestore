require_relative 'spec_helper'
require 'httpimagestore/configuration'

describe Configuration do
	subject do
		Configuration.from_file('spec/thumnailer.cfg')
	end
end

