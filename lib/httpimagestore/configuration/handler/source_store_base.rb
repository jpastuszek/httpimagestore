require 'httpimagestore/configuration/handler/statement'

module Configuration
	class SourceStoreBase < HandlerStatement
		include ImageName
		include ConditionalInclusion
		include LocalConfiguration
		include GlobalConfiguration
		include PathSpec

		def initialize(global, image_name, path_spec)
			with_global_configuration(global)
			with_image_name(image_name)
			with_path_spec(path_spec)
		end

		private

		def put_sourced_named_image(request_state)
			rendered_path = path_template.render(request_state.with_locals(local_configuration))

			image = yield @image_name, rendered_path

			image.source_path = rendered_path
			request_state.images[@image_name] = image
		end

		def get_named_image_for_storage(request_state)
			image = request_state.images[@image_name]
			rendered_path = path_template.render(request_state.with_locals(local_configuration))
			image.store_path = rendered_path

			yield @image_name, image, rendered_path
		end
	end
end

