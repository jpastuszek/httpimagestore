Feature: Stored objects should have proper Cache-Control header set
	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "hash"			"#{digest}.#{mimeextension}"
		path "hash-name"		"#{digest}-#{imagename}.#{mimeextension}"

		put "thumbnail" {
			thumbnail "input" {
				"no-cache"	operation="crop" width=128 height=128 format="jpeg"
				"cache"		operation="crop" width=256 height=256 format="jpeg"
			}

			store_s3 "input"	bucket="@AWS_S3_TEST_BUCKET@" public=true path="hash"
			store_s3 "no-cache"	bucket="@AWS_S3_TEST_BUCKET@" public=true path="hash-name"
			store_s3 "cache"	bucket="@AWS_S3_TEST_BUCKET@" public=true path="hash-name" cache-control="public, max-age=31557600, s-maxage=0"
		}
		"""
		Given httpthumbnailer server is running at http://localhost:3100/

	@cache-control
	Scenario: Image files get don't get Cache-Control header by default
		Given there is no 4006450256177f4a.jpg file in S3 bucket
		And there is no 4006450256177f4a-no-cache.jpg file in S3 bucket
		And there is no 4006450256177f4a-cache.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		OK
		"""
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a.jpg Cache-Control header will not be set
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a-no-cache.jpg Cache-Control header will not be set
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a-cache.jpg Cache-Control header will be public, max-age=31557600, s-maxage=0

