require 'unicorn-cuba-base/plugin/response_helpers'
class CubaResponseEnv
	include Plugin::ResponseHelpers

	class Response < Struct.new(:status, :data)
		extend Forwardable

		def initialize
			super
			@headers = {}
		end

		def write(data)
			(self.data ||= '') << data
		end

		def_delegators :@headers, :[]=, :[]
	end

	class Request
		class Body
			def read
				''
			end
		end

		def body
			Body.new
		end
	end

	def initialize
		@res = Response.new
		@req = Request.new
	end

	attr_reader :res
	attr_reader :req
end

