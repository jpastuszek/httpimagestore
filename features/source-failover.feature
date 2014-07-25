Feature: More than one source can be tried in canse of source problem
	Sources can be grouped under source_failover group.
	HTTP Image Store will try each source until working one is found.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "test-file"  "test.file"
		path "bogus"  "bogus"

		put "input" {
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="test-file"
		}

		get "s3_fail" {
			source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="bogus"
			source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="test-file"
			output_image "image"
		}

		get "s3_failover" {
			source_failover {
				source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="bogus"
				source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="test-file"
			}
			output_image "image"
		}

		get "s3_all_fail" {
			source_failover {
				source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="bogus"
				source_s3 "image" bucket="@AWS_S3_TEST_BUCKET@" path="bogus"
			}
			output_image "image"
		}
		"""

	@source-failover
	Scenario: Sourcing S3 object without failover
		Given there is no test.file file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/input
		Then response status will be 200
		When I do GET request http://localhost:3000/s3_fail
		Then response status will be 404

	@source-failover
	Scenario: Sourcing S3 object with failover
		Given there is no test.file file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/input
		Then response status will be 200
		When I do GET request http://localhost:3000/s3_failover
		Then response status will be 200

	@source-failover
	Scenario: Sourcing S3 object with all sources failing
		Given there is no test.file file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/input
		Then response status will be 200
		When I do GET request http://localhost:3000/s3_all_fail
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		all sources failed: S3Source[image_name: 'image' bucket: 'httpimagestoretest' prefix: '' path_spec: 'bogus'](Configuration::S3NoSuchKeyError: S3 bucket 'httpimagestoretest' does not contain key 'bogus'), S3Source[image_name: 'image' bucket: 'httpimagestoretest' prefix: '' path_spec: 'bogus'](Configuration::S3NoSuchKeyError: S3 bucket 'httpimagestoretest' does not contain key 'bogus')
		"""
