class ErrorReporter < Controller
	self.define do
		on error(
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

		on error(
			Configuration::ZeroBodyLengthError,
			Configuration::NoSpecSelectedError
		) do |error|
			write_error 400, error
		end

		on error Configuration::SourceFailoverAllFailedError do |error|
			if [Configuration::S3NoSuchKeyError, Configuration::NoSuchFileError].member? error.errors.first.class
				write_error 404, error
			else
				write_error 500, error
			end
		end

		run DefaultErrorReporter
	end
end

