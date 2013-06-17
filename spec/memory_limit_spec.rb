require_relative 'spec_helper'
require 'httpimagestore/memory_limited'

describe MemoryLimited do
	subject do
		obj = Class.new
		obj.extend MemoryLimited
		obj
	end

	it 'should raise MemoryLimitedExceededError when too much memory is borrowed' do
		subject.memory_limit = 10
		subject.borrow 8
		subject.return 3
		subject.borrow 4
		subject.borrow 1
		expect {
			subject.borrow 1
		}.to raise_error MemoryLimited::MemoryLimitedExceededError, 'requested 1 bytes when 0 bytes of limit left'
	end

	describe MemoryLimited::IO do
		it 'should limit reading from extended IO like object' do
			subject.memory_limit = 10

			test_file = Pathname.new('/tmp/memlimtest')
			test_file.open('w+') { |io|
				io.write '12345'
				io.seek 0

				io.extend MemoryLimited::IO
				io.root_limited subject
				io.read.should == '12345'

				io.seek 0
				io.write '67890'
				io.seek 0
				io.read.should == '67890'

				io.seek 0
				io.write '123'
				io.seek 0

				expect {
					io.read
				}.to raise_error MemoryLimited::MemoryLimitedExceededError, 'requested 1 bytes when 0 bytes of limit left'
			}
			test_file.unlink
		end
	end
end

