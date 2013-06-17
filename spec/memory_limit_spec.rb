require_relative 'spec_helper'
require 'httpimagestore/memory_limit'

describe MemoryLimit do
	subject do
		MemoryLimit.new(10)
	end

	it 'should raise MemoryLimitedExceededError when too much memory is borrowed' do
		subject.borrow 8
		subject.return 3
		subject.borrow 4
		subject.borrow 1
		expect {
			subject.borrow 1
		}.to raise_error MemoryLimit::MemoryLimitedExceededError, 'memory limit exceeded'
	end

	describe MemoryLimit::IO do
		it 'should limit reading from extended IO like object' do
			test_file = Pathname.new('/tmp/memlimtest')
			test_file.open('w+') { |io|
				io.write '12345'
				io.seek 0

				io.extend MemoryLimit::IO
				io.root_limit subject
				io.read.should == '12345'

				io.seek 0
				io.truncate 0
				io.write '678'
				io.seek 0
				io.read.should == '678'

				io.seek 0
				io.write '09123'
				io.seek 0

				expect {
					io.read
				}.to raise_error MemoryLimit::MemoryLimitedExceededError, 'memory limit exceeded'
			}
			test_file.unlink
		end
	end
end

