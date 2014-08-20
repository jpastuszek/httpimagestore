require_relative 'spec_helper'
require 'httpimagestore/configuration'
MemoryLimit.logger = Configuration::Scope.logger = RootLogger.new('/dev/null')

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

	describe Configuration::SDL4RTagExtensions do
		let :configuration do
			SDL4R::read <<-'EOF'
			test "hello" "world" abc=123 xyz=321 qwe=true asd="fd"
			EOF
		end

		subject do
			configuration.children.first
		end

		describe '#required_attributes' do
			it 'should raise NoAttributeError if there is missing required attribute' do
				subject.required_attributes('abc', 'xyz')

				expect {
					subject.required_attributes('abc', 'xyz', 'blah')
				}.to raise_error Configuration::NoAttributeError, %{syntax error while parsing 'test "hello" "world" abc=123 asd="fd" qwe=true xyz=321': expected 'blah' attribute to be set}
			end
		end

		describe '#grab_attributes' do
			it 'should grab list of attributes form node' do
				list = subject.grab_attributes('abc', 'xyz', 'qwe', 'opt', 'asd')
				list.should == [123, 321, true, nil, 'fd']
			end

			it 'should raise UnexpectedAttributesError if unlisted attribut is on closed attribute list' do
				expect {
					subject.grab_attributes('abc', 'qwe')
				}.to raise_error Configuration::UnexpectedAttributesError, %{syntax error while parsing 'test "hello" "world" abc=123 asd="fd" qwe=true xyz=321': unexpected attributes: 'xyz', 'asd'}
			end
		end

		describe '#grab_attributes_with_remaining' do
			it 'should grab list of attributes form node and all other remaining attributes' do
				*list, remaining = *subject.grab_attributes_with_remaining('abc', 'xyz')
				list.should == [123, 321]
				remaining.should == {'qwe' => true, 'asd' => 'fd'}
			end
		end

		describe '#valid_attribute_values' do
			it 'should rise BadAttributeValueError if attribute value is not on defined value list' do
				subject.valid_attribute_values('qwe', true, false)

				expect {
					subject.valid_attribute_values('qwe', 'hello', 'world')
				}.to raise_error Configuration::BadAttributeValueError, %{syntax error while parsing 'test "hello" "world" abc=123 asd="fd" qwe=true xyz=321': expected 'qwe' attribute value to be "hello" or "world"; got: true}
			end
		end

		describe '#grab_values' do
			it 'should grab list of values' do
				subject.grab_values('value 1', 'value 2').should == ['hello', 'world']
			end

			it 'should raise NoValueError if there is not enought values' do
				expect {
					subject.grab_values('value 1', 'value 2', 'value 3')
				}.to raise_error Configuration::NoValueError, %{syntax error while parsing 'test "hello" "world" abc=123 asd="fd" qwe=true xyz=321': expected value 3}
			end

			it 'should raise UnexpectedValueError if there is too many values' do
				expect {
					subject.grab_values('value 1')
				}.to raise_error Configuration::UnexpectedValueError, %{syntax error while parsing 'test "hello" "world" abc=123 asd="fd" qwe=true xyz=321': unexpected values: "world"}
			end
		end
	end
end

