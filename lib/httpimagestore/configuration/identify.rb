require 'httpthumbnailer-client'
require 'httpimagestore/ruby_string_template'
require 'httpimagestore/configuration/handler'

module Configuration
	class Identify < HandlerStatement
		include ClassLogging

		extend Stats
		def_stats(
			:total_identify_requests,
			:total_identify_requests_bytes
		)

		def self.match(node)
			node.name == 'identify'
		end

		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first
			if_image_name_on = node.grab_attributes('if-image-name-on').first

			iden = self.new(configuration.global, image_name)
			iden.push_inclusion_matchers(InclusionMatcher.new(image_name, if_image_name_on)) if if_image_name_on

			configuration.processors << iden
		end

		include ImageName
		include ConditionalInclusion

		def initialize(global, image_name)
			super(global, image_name)
		end

		def realize(request_state)
			client = @global.thumbnailer or fail 'thumbnailer configuration'
			image = request_state.images[@image_name]

			log.info "identifying '#{@image_name}'"

			Identify.stats.incr_total_identify_requests
			Identify.stats.incr_total_identify_requests_bytes image.data.bytesize

			id = client.with_headers(request_state.headers).identify(image.data)

			image.mime_type = id.mime_type if id.mime_type
			image.width = id.width if id.width
			image.height = id.height if id.height
			log.info "image '#{@image_name}' identified as '#{id.mime_type}' #{image.width}x#{image.height}"
		end
	end
	Handler::register_node_parser Identify
	StatsReporter << Identify.stats
end

