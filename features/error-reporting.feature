Feature: Image list based thumbnailing and S3 storage
	Storage based on URL specified image names to be generated and stored using two different path formats.
	This configuration should be mostly compatible with pre v1.0 release.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "structured-name"	"#{dirname}/#{digest}/#{basename}-#{imagename}.#{mimeextension}"
		path "missing"		"blah"

		put "thumbnail" ":name_list" {
			thumbnail "input" {
				"small"		operation="crop"	width=128	height=128			    if-image-name-on="#{name_list}"
				"bad"		operation="crop"	width=0		height=0			    if-image-name-on="#{name_list}"
				"superlarge"	operation="crop"	width=16000	height=16000			    if-image-name-on="#{name_list}"
				"large_png"	operation="crop"	width=7000	height=7000	format="png"	    if-image-name-on="#{name_list}"
				"bad_opts"	operation="crop"	width=128	height=128	options="foo=bar"   if-image-name-on="#{name_list}"
			}
		}

		get "s3" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="missing"
		}

		get "file" {
			source_file "original" root="/tmp" path="missing"
		}
		"""
		Given httpthumbnailer server is running at http://localhost:3100/

	@error-reporting
	Scenario: Reporting of missing resource
		When I do GET request http://localhost:3000/blah
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		request for URI '/blah' was not handled by the server
		"""

	@error-reporting
	Scenario: Reporting of missing S3 resource
		When I do GET request http://localhost:3000/s3
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		S3 bucket 'httpimagestoretest' does not contain key 'blah'
		"""

	@error-reporting
	Scenario: Reporting of missing file resource
		When I do GET request http://localhost:3000/file
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		error while processing image 'original': file 'blah' not found
		"""

	@error-reporting
	Scenario: Reporting of unsupported media type
		Given test.txt file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny
		Then response status will be 415
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		unsupported media type: no decode delegate for this image format
		"""

	@error-reporting
	Scenario: Reporting and handling of thumbnailing errors
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,bad
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'bad' failed: at least one image dimension is zero: 0x0
		"""

	@error-reporting
	Scenario: Reporting and handling of thumbnailing errors - bad options format
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,bad_opts
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		missing option value for key 'foo=bar'
		"""

	@error-reporting
	Scenario: Too large image - uploaded image too big to fit in memory limit
		Given test-large.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/large_png
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		image too large: cache resources exhausted
		"""

	@error-reporting
	Scenario: Too large image - memory exhausted when thmbnailing
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/superlarge
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'superlarge' failed: image too large: cache resources exhausted
		"""

	@error-reporting
	Scenario: Zero body length
		Given test.empty file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		empty body - expected image data
		"""

