class ErrorReporter < Controler
	self.define do
		on error Rack::UnhandledRequest::UnhandledRequestError do
			write_error 404, env['app.error']
		end

		on error HTTPThumbnailerClient::UnsupportedMediaTypeError do
			write_error 415, env['app.error']
		end

		on error HTTPThumbnailerClient::ImageTooLargeError do
			write_error 413, env['app.error']
		end

		#on error ThumbnailingError do
		#	write_error env['app.error'].remote_error.status, env['app.error']
		#end

		#on error(
		#	ThumbnailClassDoesNotExistError,
		#	ZeroBodyLengthError
		#) do
		#	write_error 400, env['app.error']
		#end

		log.error "unhandled error while processing request: #{env['REQUEST_METHOD']} #{env['SCRIPT_NAME']}[#{env["PATH_INFO"]}]", env['app.error']
		log.debug {
			out = StringIO.new
			PP::pp(env, out, 200)
			"Request: \n" + out.string
		}

		on error StandardError do
			write_error 500, env['app.error']
		end
	end
end

