require 'httpthumbnailer-client'

module Plugin
	module Thumbnailer
		include ClassLogging

		def self.setup(app)
			self.logger = app.logger_for(Thumbnailer)
			log.info "initializing thumbnailer client with #{app.settings[:thumbnailer_url]}"
			@@service = HTTPThumbnailerClient.new(app.settings[:thumbnailer_url])
		end

		def thumbnailer
			@@service
		end
	end
end

