module Configuration
	class S3 < Struct.new(:key, :secret)
		def self.match(node)
			node.name == 's3'
		end

		def self.parse(configuration, node)
			key = node.attribute('key') or raise MissingArgumentError, 's3 key'
			secret = node.attribute('secret') or raise MissingArgumentError, 's3 secret'
			configuration.s3 = self.new(key, secret)
		end
	end
	Global.register_node_parser S3
end

