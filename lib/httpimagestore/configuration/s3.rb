module Configuration
	class S3
		def self.match(node)
			node.name == 's3'
		end

		def self.parse(configuration, node)
			configuration.s3 = Struct.new(:key, :secret).new
			configuration.s3.key = node.attribute('key') or raise MissingArgumentError, 's3 key'
			configuration.s3.secret = node.attribute('secret') or raise MissingArgumentError, 's3 secret'
		end
	end
	Global.register_node_parser S3
end

