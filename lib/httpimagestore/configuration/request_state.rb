require 'mime/types'
require 'digest/sha2'
require 'securerandom'

module Configuration
	class RequestState < Hash
		include ClassLogging

		class Images < Hash
			def initialize(memory_limit)
				@memory_limit = memory_limit
				super
			end

			def []=(name, image)
				if member?(name)
					@memory_limit.return fetch(name).data.bytesize
				end
				super
			end

			def [](name)
				fetch(name){|image_name| raise ImageNotLoadedError.new(image_name)}
			end
		end

		def initialize(body, matches, path, query_string, request_uri, request_headers, memory_limit, forward_headers)
			super() do |request_state, name|
				# note that request_state may be different object when useing with_locals that creates duplicate
				request_state[name] = request_state.generate_meta_variable(name) or raise VariableNotDefinedError.new(name)
			end

			# it is OK to overwrite path with a match
			self[:path] = path

			merge! matches

			log.debug "processing request with body length: #{body.bytesize} bytes and variables: #{map{|k,v| "#{k}: '#{v}'"}.join(', ')}"

			@body = body
			@images = Images.new(memory_limit)
			@query_string = query_string
			@request_uri = request_uri
			@request_headers = request_headers
			@memory_limit = memory_limit
			@output_callback = nil

			@forward_headers = forward_headers
		end

		attr_reader :body
		attr_reader :images
		attr_reader :memory_limit
		attr_reader :query_string
		attr_reader :request_uri
		attr_reader :request_headers
		attr_reader :forward_headers

		def with_locals(*locals)
			locals = locals.reduce{|a, b| a.merge(b)}
			log.debug "using additional local variables: #{locals}"
			self.dup.merge!(locals)
		end

		def output(&callback)
			@output_callback = callback
		end

		def output_callback
			@output_callback or fail 'no output callback'
		end

		def fetch_base_variable(name, base_name)
			fetch(base_name, nil) or generate_meta_variable(base_name) or raise NoVariableToGenerateMetaVariableError.new(base_name, name)
		end

		def generate_meta_variable(name)
			val = case name
			when :basename
				path = Pathname.new(fetch_base_variable(name, :path))
				path.basename(path.extname).to_s
			when :dirname
				Pathname.new(fetch_base_variable(name, :path)).dirname.to_s
			when :extension
				Pathname.new(fetch_base_variable(name, :path)).extname.delete('.')
			when :digest # deprecated
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s[0,16]
			when :input_digest
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s[0,16]
			when :input_sha256
				@body.empty? and raise NoRequestBodyToGenerateMetaVariableError.new(name)
				Digest::SHA2.new.update(@body).to_s
			when :input_image_width
				@images['input'].width or raise NoImageDataForVariableError.new('input', name)
			when :input_image_height
				@images['input'].height or raise NoImageDataForVariableError.new('input', name)
			when :input_image_mime_extension
				@images['input'].mime_extension or raise NoImageDataForVariableError.new('input', name)
			when :image_digest
				Digest::SHA2.new.update(@images[fetch_base_variable(name, :image_name)].data).to_s[0,16]
			when :image_sha256
				Digest::SHA2.new.update(@images[fetch_base_variable(name, :image_name)].data).to_s
			when :mimeextension # deprecated
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].mime_extension or raise NoImageDataForVariableError.new(image_name, name)
			when :image_mime_extension
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].mime_extension or raise NoImageDataForVariableError.new(image_name, name)
			when :image_width
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].width or raise NoImageDataForVariableError.new(image_name, name)
			when :image_height
				image_name = fetch_base_variable(name, :image_name)
				@images[image_name].height or raise NoImageDataForVariableError.new(image_name, name)
			when :uuid
				SecureRandom.uuid
			when :query_string_options
				query_string.sort.map{|kv| kv.join(':')}.join(',')
			end
			if val
				log.debug  "generated meta variable '#{name}': #{val}"
			else
				log.debug  "could not generated meta variable '#{name}'"
			end
			val
		end
	end
end

