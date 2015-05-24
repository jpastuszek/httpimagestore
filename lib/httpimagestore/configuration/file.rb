require 'httpimagestore/configuration/path'
require 'httpimagestore/configuration/handler/source_store_base'
require 'httpimagestore/configuration/source_failover'
require 'pathname'
require 'addressable/uri'

module Configuration
	class FileStorageOutsideOfRootDirError < ConfigurationError
		def initialize(image_name, file_path)
			super "error while processing image '#{image_name}': file storage path '#{file_path.to_s}' outside of root direcotry"
		end
	end

	class NoSuchFileError < ConfigurationError
		def initialize(image_name, file_path)
			super "error while processing image '#{image_name}': file '#{file_path.to_s}' not found"
		end
	end

	class FileSourceStoreBase < SourceStoreBase
		extend Stats
		def_stats(
			:total_file_store,
			:total_file_store_bytes,
			:total_file_source,
			:total_file_source_bytes
		)

		def self.parse(configuration, node)
			image_name = node.grab_values('image name').first
			node.required_attributes('root', 'path')

			# TODO: it should be possible to compact that
			root_dir, path_spec, remaining = *node.grab_attributes_with_remaining('root', 'path')
			conditions, remaining = *ConditionalInclusion.grab_conditions_with_remaining(remaining)
			remaining.empty? or raise UnexpectedAttributesError.new(node, remaining)

			file = self.new(
				configuration.global,
				image_name,
				root_dir,
				path_spec
			)
			file.with_conditions(conditions)
			file
		end

		def initialize(global, image_name, root_dir, path_spec)
			super(global, image_name, path_spec)
			@root_dir = Pathname.new(root_dir).cleanpath
		end

		def storage_path(rendered_path)
			path = Pathname.new(rendered_path)

			storage_path = (@root_dir + path).cleanpath
			storage_path.to_s =~ /^#{@root_dir.to_s}/ or raise FileStorageOutsideOfRootDirError.new(image_name, path)

			storage_path
		end

		def file_url(rendered_path)
			uri = rendered_path.to_uri
			uri.scheme = 'file'
			uri
		end

		def to_s
			"FileSource[image_name: '#{image_name}' root_dir: '#{@root_dir}' path_spec: '#{path_spec}']"
		end
	end

	class FileSource < FileSourceStoreBase
		include ClassLogging

		def self.match(node)
			node.name == 'source_file'
		end

		def self.parse(configuration, node)
			configuration.sources << super
		end

		def realize(request_state)
			put_sourced_named_image(request_state) do |image_name, rendered_path|
				storage_path = storage_path(rendered_path)

				log.info "sourcing '#{image_name}' from file '#{storage_path}'"
				begin
					data = storage_path.open('rb') do |io|
						request_state.memory_limit.io io
						io.read
					end
					FileSourceStoreBase.stats.incr_total_file_source
					FileSourceStoreBase.stats.incr_total_file_source_bytes(data.bytesize)

					image = Image.new(data)
					image.source_url = file_url(rendered_path)
					image
				rescue Errno::ENOENT
					raise NoSuchFileError.new(image_name, rendered_path)
				end
			end
		end
	end
	Handler::register_node_parser FileSource
	SourceFailover::register_node_parser FileSource

	class FileStore < FileSourceStoreBase
		include ClassLogging

		def self.match(node)
			node.name == 'store_file'
		end

		def self.parse(configuration, node)
			configuration.stores << super
		end

		def realize(request_state)
			get_named_image_for_storage(request_state) do |image_name, image, rendered_path|
				storage_path = storage_path(rendered_path)

				image.store_url = file_url(rendered_path)

				log.info "storing '#{image_name}' in file '#{storage_path}' (#{image.data.length} bytes)"
				storage_path.open('wb'){|io| io.write image.data}
				FileSourceStoreBase.stats.incr_total_file_store
				FileSourceStoreBase.stats.incr_total_file_store_bytes(image.data.bytesize)
			end
		end
	end
	Handler::register_node_parser FileStore
	StatsReporter << FileSourceStoreBase.stats
end

