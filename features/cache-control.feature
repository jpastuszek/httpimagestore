Feature: Stored objects should have proper Cache-Control header set

	Background:
		Given issthumbtest S3 bucket with key AKIAJMUYVYOSACNXLPTQ and secret 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
		Given httpimagestore log is empty
		Given httpthumbnailer log is empty
		Given httpthumbnailer server is running at http://localhost:3100/
		Given Content-Type header set to image/autodetect

	@cache-control
	Scenario: Image files get Cache-Control header with max-age set by default
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		"""
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/image/test
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg Cache-Control header will be public, max-age=31557600
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg Cache-Control header will be public, max-age=31557600

	@cache-control
	Scenario: Image files get Cache-Control header defined with argument
		Given httpimagestore argument --cache-control 'private, max-age=300, s-maxage=300'
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		"""
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/image/test
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg Cache-Control header will be private, max-age=300, s-maxage=300
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg Cache-Control header will be private, max-age=300, s-maxage=300

	@cache-control
	Scenario: Image files get Cache-Control header defined with argument
		Given httpimagestore argument --cache-control 'private'
		Given httpimagestore argument --cache-control 'max-age=300'
		Given httpimagestore argument --cache-control 's-maxage=300'
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		"""
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/image/test
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg Cache-Control header will be private, max-age=300, s-maxage=300
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg Cache-Control header will be private, max-age=300, s-maxage=300

	@cache-control
	Scenario: Image files get Cache-Control header undefined when set to ''
		Given httpimagestore argument --cache-control ''
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		"""
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/image/test
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg Cache-Control header will not be set
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg Cache-Control header will not be set

