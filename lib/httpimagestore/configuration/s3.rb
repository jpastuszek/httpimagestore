module Configuration
	class S3
		include ClassLogging

		def self.match(node)
			node.name == 's3'
		end

		def self.parse(configuration, node)
			configuration.s3 and raise StatementCollisionError.new(node, 's3')
			configuration.s3 = Struct.new(:key, :secret).new
			configuration.s3.key = node.attribute('key') or raise NoAttributeError.new(node, 'key')
			configuration.s3.secret = node.attribute('secret') or raise NoAttributeError.new(node, 'secret')

			log.info "using #{configuration.s3.key} S3 credentials"
		end
	end
	Global.register_node_parser S3
end

