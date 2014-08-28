require_relative 'spec_helper'
require 'httpimagestore/ruby_string_template'

describe RubyStringTemplate do
	subject do
		RubyStringTemplate.new('>#{hello}-#{world}#{test}<')
	end

	it 'should replace holders with given values' do
		subject.render(hello: 'hello', world: 'world', test: 123).should == '>hello-world123<'
	end

	it 'should raise NoValueForTemplatePlaceholderError if template value was not provided' do
		expect {
			subject.render(hello: 'hello', test: 123)
		}.to raise_error RubyStringTemplate::NoValueForTemplatePlaceholderError, %q{no value for '#{world}' in template '>#{hello}-#{world}#{test}<'}
	end

	it 'should not process nested placeholders' do
		subject.render(hello: '#{nested}', world: 'world', test: 123, nested: 'xxx').should == '>#{nested}-world123<'
		subject.render(hello: '#{world}', world: 'world', test: 123, nested: 'xxx').should == '>#{world}-world123<'
	end

	describe 'with custom resolver' do
		subject do
			RubyStringTemplate.new('>#{hello}-#{world}#{test}<') do |locals, name|
				case name
				when :test
					321
				else
					locals[name]
				end
			end
		end

		it 'should ask for values using provided resolver' do
			subject.render(hello: 'hello', world: 'world').should == '>hello-world321<'
			subject.render(hello: 'hello', world: 'world', test: 123).should == '>hello-world321<'
		end

		it 'should raise NoValueForTemplatePlaceholderError if template value was not provided' do
			expect {
				subject.render(hello: 'hello', test: 123)
			}.to raise_error RubyStringTemplate::NoValueForTemplatePlaceholderError, %q{no value for '#{world}' in template '>#{hello}-#{world}#{test}<'}
		end

		it 'should allow using custom missing value resolver' do
			template = subject
			expect {
				template.with_missing_resolver do |locals, key|
					fail "missing key: #{key}"
				end
				.render(hello: 'hello', test: 123)
			}.to raise_error RuntimeError, "missing key: world"

			expect {
				template.render(hello: 'hello', test: 123)
			}.to raise_error RubyStringTemplate::NoValueForTemplatePlaceholderError, %q{no value for '#{world}' in template '>#{hello}-#{world}#{test}<'}
		end
	end
end

