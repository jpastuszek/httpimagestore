module MemoryLimited
	class MemoryLimitedExceededError < RuntimeError
		def initialize(limit, requested)
			super "requested #{requested} bytes when #{limit} bytes of limit left"
		end
	end

	module IO
		def root_limited(ml)
			@root_limited = ml
		end
		
		def read
			data = super(@root_limited.limit)
			raise MemoryLimitedExceededError.new(@root_limited.limit, @root_limited.limit + 1) if data.length == @root_limited.limit and super(1)
			@root_limited.borrow(data.length)
			data
		end
	end	

	def memory_limit=(bytes)
		@limit = bytes
	end

	attr_reader :limit

	def borrow(bytes)
		return unless @limit
		bytes > @limit and raise MemoryLimitedExceededError.new(@limit, bytes)
		@limit -= bytes
	end

	def return(bytes)
		return unless @limit
		@limit += bytes
	end
end

