class ErrorReporter < Controler
	self.define do
		on error(
			Rack::UnhandledRequest::UnhandledRequestError,
			Configuration::S3NoSuchKeyError,
			Configuration::NoSuchFileError
		)	do |error|
			write_error 404, error
		end

		on error MemoryLimit::MemoryLimitedExceededError do |error|
			write_error 413, error
		end

		on error Configuration::Thumbnail::ThumbnailingError do |error|
			status = defined?(error.remote_error.status) ? error.remote_error.status : 500
			write_error status, error
		end

		on error Configuration::ZeroBodyLengthError do |error|
			write_error 400, error
		end

		on error StandardError do |error|
			log.error "unhandled error while processing request: #{env['REQUEST_METHOD']} #{env['SCRIPT_NAME']}[#{env["PATH_INFO"]}]", error
			log.debug {
				out = StringIO.new
				PP::pp(env, out, 200)
				"Request: \n" + out.string
			}

			write_error 500, error
		end
	end
end

