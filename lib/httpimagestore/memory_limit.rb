require 'unicorn-cuba-base'

class MemoryLimit
	include ClassLogging

	class MemoryLimitedExceededError < RuntimeError
		def initialize
			super "memory limit exceeded"
		end
	end

	module IO
		def root_limit(ml)
			@root_limit = ml
		end
		
		def read
			data = @root_limit.get do |max_read_bytes|
				super max_read_bytes + 1 or return '' # read() always returns '' on EOF
			end
		end
	end	

	def initialize(bytes = 256 * 1024 ** 2)
		log.info "using memory limit of #{bytes} bytes" if bytes
		@limit = bytes
	end

	attr_reader :limit

	def get
		yield(@limit).tap do |data|
			borrow data.bytesize if data
		end
	end

	def borrow(bytes)
		log.debug "borrowing #{bytes} from #{@limit} bytes of limit"
		bytes > @limit and raise MemoryLimitedExceededError.new
		@limit -= bytes
	end

	def return(bytes)
		log.debug "returning #{bytes} to #{@limit} bytes of limit"
		@limit += bytes
	end

	def io(io)
		io.extend MemoryLimit::IO
		io.root_limit self
		io
	end
end

