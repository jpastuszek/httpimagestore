## HACK: Auto select region based on location_constraint
module AWS
	class S3
		class BucketCollection
			def [](name)
				# if name is DNS compatible we still cannot use it for writes if it does contain dots
				return S3::Bucket.new(name.to_s, :owner => nil, :config => config) if client.dns_compatible_bucket_name?(name) and not name.include? '.'

				# save region mapping for bucket for futher requests
				@@location_cache = {} unless defined? @@location_cache
				# if we have it cased use it; else try to fetch it and if it is nil bucket is in standard region
				region = @@location_cache[name] || @@location_cache[name] = S3::Bucket.new(name.to_s, :owner => nil, :config => config).location_constraint || @@location_cache[name] = :standard

				# no need to specify region if bucket is in standard region
				return S3::Bucket.new(name.to_s, :owner => nil, :config => config) if region == :standard

				# use same config but with region specified for buckets that are not DNS compatible or have dots and are not in standard region
				S3::Bucket.new(name.to_s, :owner => nil, :config => config.with(region: region))
			end
		end
	end
end

