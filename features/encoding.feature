Feature: Encoded UTF-8 URI support
	HTTP Image Store should be able to decode UTF-8 characters form URI using URI decode and also support JavaScript encode() format.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false
		path "path"             "#{path}"

		post "file" "encoding" "encoded" {
			store_file "input" root="/tmp" path="path"
			output_store_uri "input" path="path"
		}

		post "file" "encoding" "decoded" {
			store_file "input" root="/tmp" path="path"
			output_store_path "input" path="path"
		}

		post "s3" "encoding" "encoded" {
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			output_store_uri "input" path="path"
		}

		post "s3" "encoding" "decoded" {
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			output_store_path "input" path="path"
		}
		"""

	Scenario: JavaScript encode() + URL encoded variable decoding and URL encoding for file based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/file/encoding/encoded/triple%20kro%25u0301l.png
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		/triple%20kr%C3%B3l.png
		"""

	Scenario: JavaScript encode() + URL encoded variable decoding and URL encoding for S3 based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/s3/encoding/encoded/triple%20kro%25u0301l.png
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		/triple%20kr%C3%B3l.png
		"""

	Scenario: URL encoded variable decoding and URL encoding with ? for file based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/file/encoding/encoded/hello%3Fworld.png
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		/hello%3Fworld.png
		"""

	Scenario: URL encoded variable decoding and URL encoding with ? for S3 based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/s3/encoding/encoded/hello%3Fworld.png
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		/hello%3Fworld.png
		"""

	Scenario: URL encoded variable decoding for file based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/file/encoding/decoded/triple%20kr%C3%B3l.png
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		triple król.png
		"""

	Scenario: URL encoded variable decoding for S3 based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/s3/encoding/decoded/triple%20kr%C3%B3l.png
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		triple król.png
		"""

	Scenario: URL path normalization with ? for file based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/file/encoding/decoded/hello%3Fworld.png
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		hello?world.png
		"""

	Scenario: URL path normalization with ? S3 file based storage
		Given test.png file content as request body
		When I do POST request http://localhost:3000/s3/encoding/decoded/hello%3Fworld.png
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		hello?world.png
		"""
