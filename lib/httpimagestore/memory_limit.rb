require 'unicorn-cuba-base'

class MemoryLimit
	include ClassLogging

	class MemoryLimitedExceededError < RuntimeError
		def initialize
			super "memory limit exceeded"
		end
	end

	module IO
		include ClassLogging

		def root_limit(ml)
			@root_limit = ml
		end
		
		def read
			max_read_bytes = @root_limit.limit
			data = super(max_read_bytes)
			@root_limit.borrow(data.length)
			if data.bytesize == max_read_bytes and super(1)
				IO.log.warn "remaining memory limit of #{max_read_bytes} bytes is not enoguht to hold data from IO '#{self.inspect}'"
				raise MemoryLimitedExceededError.new
			end
			data
		end
	end	

	def initialize(bytes = nil)
		log.info "using memory limit of #{bytes} bytes" if bytes
		@limit = bytes
	end

	attr_reader :limit

	def borrow(bytes)
		return unless @limit
		log.debug "borrowing #{bytes} from #{@limit} bytes of limit"
		bytes > @limit and raise MemoryLimitedExceededError.new
		@limit -= bytes
	end

	def return(bytes)
		return unless @limit
		log.debug "returning #{bytes} to #{@limit} bytes of limit"
		@limit += bytes
	end
end

