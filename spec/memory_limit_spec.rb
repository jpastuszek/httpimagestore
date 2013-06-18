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

	describe '#get' do
		it 'should yield limit left and borrow as much as returned string bytesize' do
			subject.get do |limit|
				limit.should == 10
				'123'
			end.should == '123'
			subject.limit.should == 7
		end

		it 'should raise MemoryLimit::MemoryLimitedExceededError if retruned string is longer than the limit' do
			expect {
				subject.get do |limit|
					'12345678901'
				end
			}.to raise_error MemoryLimit::MemoryLimitedExceededError
		end
	end

	describe MemoryLimit::IO do
		it 'should limit reading from extended IO like object' do
			test_file = Pathname.new('/tmp/memlimtest')
			test_file.open('w+') { |io|
				io.write '12345'
				io.seek 0

				subject.io io
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

