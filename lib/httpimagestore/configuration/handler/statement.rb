require 'httpimagestore/configuration'
require 'httpimagestore/configuration/handler'

module Configuration
	class HandlerStatement < Scope
		# Base class for all statements that are within get/post/put/delete handler
		#
		module LocalConfiguration
			attr_reader :local_configuration
			def config_local(name, value)
				@local_configuration ||= {}
				@local_configuration[name] = value
			end
		end

		module ImageName
			attr_reader :image_name

			def with_image_name(image_name)
				@image_name = image_name
				config_local :imagename, @image_name # deprecated
				config_local :image_name, @image_name
				self
			end
		end

		module GlobalConfiguration
			attr_reader :global
			def with_global_configuration(global)
				@global = global
			end

			def path_template(path_spec)
				@global.paths[path_spec]
			end
		end

		module PathSpec
			attr_reader :path_spec

			def with_path_spec(path_spec)
				@path_spec = path_spec
				self
			end

			# this is more specific than GlobalConfiguration
			def path_template
				@global.paths[@path_spec]
			end
		end

		module ConditionalInclusion
			class ImageNameOn
				def initialize(template)
					@template = template.to_template
				end

				def included?(request_state)
					image_name = request_state[:image_name]
					@template.render(request_state).split(',').include? image_name
				end
			end

			class VariableMatches
				def initialize(value)
					param_name, template = value.split(':', 2)
					@param_name = param_name.to_sym if param_name
					@template = template.to_template if template
				end

				def included?(request_state)
					return false if not @param_name
					return request_state[@param_name] == 'true' if not @template
					@template.render(request_state) == request_state[@param_name]
				rescue Configuration::VariableNotDefinedError
					false
				end
			end

			def self.grab_conditions_with_remaining(attributes)
				conditions = []
				attributes = attributes.dup

				if_image_name_on = attributes.delete('if-image-name-on')
				conditions << ConditionalInclusion::ImageNameOn.new(if_image_name_on) if if_image_name_on

				if_image_name_on = attributes.delete('if-variable-matches')
				conditions << ConditionalInclusion::VariableMatches.new(if_image_name_on) if if_image_name_on

				[conditions, attributes]
			end

			def with_conditions(conditions)
				@conditions ||= []
				@conditions.push(*conditions)
				self
			end

			def included?(request_state)
				return true if not @conditions or @conditions.empty?
				# some conditions may use local_configuration vars
				request_state = request_state.with_locals(local_configuration) if @local_configuration
				@conditions.all? do |matcher|
					matcher.included?(request_state)
				end
			end

			def excluded?(request_state)
				not included? request_state
			end
		end
	end
end

