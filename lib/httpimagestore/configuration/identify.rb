require 'httpthumbnailer-client'
require 'httpimagestore/ruby_string_template'
require 'httpimagestore/configuration/handler'

module Configuration
	class Identify < HandlerStatement
		include ClassLogging
		include ImageName
		include LocalConfiguration
		include GlobalConfiguration
		include ConditionalInclusion
		include PerfStats

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

			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(node.attributes)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			iden = self.new(configuration.global, image_name)
			iden.with_conditions(conditions)

			configuration.processors << iden
		end

		def initialize(global, image_name)
			with_global_configuration(global)
			with_image_name(image_name)
		end

		def realize(request_state)
			client = @global.thumbnailer or fail 'thumbnailer configuration'
			image = request_state.images[@image_name]

			log.info "identifying '#{@image_name}'"

			Identify.stats.incr_total_identify_requests
			Identify.stats.incr_total_identify_requests_bytes image.data.bytesize

			id = measure "identifying", @image_name do
				client.with_headers(request_state.forward_headers).identify(image.data)
			end

			image.mime_type = id.mime_type if id.mime_type
			image.width = id.width if id.width
			image.height = id.height if id.height
			log.info "image '#{@image_name}' identified as '#{id.mime_type}' #{image.width}x#{image.height}"
		end
	end
	Handler::register_node_parser Identify
	StatsReporter << Identify.stats
end

