require 'httpthumbnailer-client'
require 'httpimagestore/ruby_string_template'
require 'httpimagestore/configuration/handler'

module Configuration
	class Identify
		include ClassLogging

		extend Stats
		def_stats(
			:total_identify_requests, 
			:total_identify_requests_bytes
		)

		include ConditionalInclusion

		def self.match(node)
			node.name == 'identify'
		end

		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first
			if_image_name_on = node.grab_attributes('if-image-name-on').first

			matcher = InclusionMatcher.new(image_name, if_image_name_on) if if_image_name_on

			configuration.image_sources << self.new(configuration.global, image_name, matcher)
		end

		def initialize(global, image_name, matcher = nil)
			@global = global
			@image_name = image_name
			inclusion_matcher matcher if matcher
		end

		def realize(request_state)
			client = @global.thumbnailer or fail 'thumbnailer configuration'
			image = request_state.images[@image_name]

			log.info "identifying '#{@image_name}'"

			Identify.stats.incr_total_identify_requests
			Identify.stats.incr_total_identify_requests_bytes image.data.bytesize

			id = client.identify(image.data)

			image.mime_type = id.mime_type if id.mime_type
			log.info "image '#{@image_name}' identified as '#{id.mime_type}'"
		end
	end
	Handler::register_node_parser Identify
	StatsReporter << Identify.stats
end

