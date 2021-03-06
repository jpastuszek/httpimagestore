Feature: Error handling
	API should provide different status codes with text/plain description body for different error modes.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "uri_part"         "/thumbnails/#{input_digest}/#{name}.#{image_mime_extension}"
		path "structured-name"  "#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{image_mime_extension}"
		path "missing"          "blah"
		path "zero"             "zero"
		path "hash"             "#{input_digest}"

		put "multipart" ":name_list" {
			thumbnail "input" {
				"small"             operation="crop"        width=128       height=128                              if-image-name-on="#{name_list}"
				"tiny"              operation="crop"        width=10        height=10                               if-image-name-on="#{name_list}"
				"bad"               operation="crop"        width=0         height=0                                if-image-name-on="#{name_list}"
				"bad_dim"           operation="crop"        width="128x"    height=128                              if-image-name-on="#{name_list}"
				"superlarge"        operation="crop"        width=16000     height=16000                            if-image-name-on="#{name_list}"
				"large_png"         operation="crop"        width=7000      height=7000     format="png"            if-image-name-on="#{name_list}"
				"bad_opts"          operation="crop"        width=128       height=128      options="foo=bar"       if-image-name-on="#{name_list}"
			}
		}

		put "singlepart" ":name_list" {
			thumbnail "input"    "small"         operation="crop"        width=128       height=128                              if-image-name-on="#{name_list}"
			thumbnail "input"    "bad"           operation="crop"        width=0         height=0                                if-image-name-on="#{name_list}"
			thumbnail "input"    "bad_dim"       operation="crop"        width="128x"    height=128                              if-image-name-on="#{name_list}"
			thumbnail "input"    "superlarge"    operation="crop"        width=16000     height=16000                            if-image-name-on="#{name_list}"
			thumbnail "input"    "large_png"     operation="crop"        width=7000      height=7000     format="png"            if-image-name-on="#{name_list}"
			thumbnail "input"    "bad_opts"      operation="crop"        width=128       height=128      options="foo=bar"       if-image-name-on="#{name_list}"
		}

		post "filename" "/(?<name>.+?)(\\.[^\\.]+)?$/" {
			identify "input"
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="hash" cache-root="/tmp"
			output_store_path "input" path="uri_part"
		}

		get "s3" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="missing"
		}

		get "file" {
			source_file "original" root="/tmp" path="missing"
		}

		get "zero" {
			source_file "original" root="/dev" path="zero"
		}

		path "not_defined" "#{bogous}"
		get "not_defined" {
			source_file "original" root="/tmp" path="not_defined"
		}

		path "body" "#{input_digest}"
		get "body" {
			source_file "original" root="/tmp" path="body"
		}

		path "no_image_meta" "#{image_mime_extension}"
		put "no_image_meta" {
			store_file "input" root="/tmp" path="no_image_meta"
		}
		"""

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
		When I do PUT request http://localhost:3000/multipart/small,tiny
		Then response status will be 415
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' failed: unsupported media type: no decode delegate for this image format
		"""
		When I do PUT request http://localhost:3000/singlepart/small,tiny
		Then response status will be 415
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'small' failed: unsupported media type: no decode delegate for this image format
		"""

	@error-reporting
	Scenario: Reporting and handling of thumbnailing errors
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/multipart/small,bad
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'bad' failed: at least one image dimension is zero: 0x0
		"""
		When I do PUT request http://localhost:3000/singlepart/small,bad
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'bad' failed: at least one image dimension is zero: 0x0
		"""

	@error-reporting
	Scenario: Reporting and handling of thumbnailing errors - bad options format
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/multipart/small,bad_opts
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		thumbnail spec 'bad_opts' is invalid: options spec 'foo=bar' format is invalid: missing option value for key 'foo=bar'
		"""
		When I do PUT request http://localhost:3000/singlepart/small,bad_opts
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		thumbnail spec 'bad_opts' is invalid: options spec 'foo=bar' format is invalid: missing option value for key 'foo=bar'
		"""

	@error-reporting
	Scenario: Bad dimension
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/multipart/bad_dim,small
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnail spec 'bad_dim' is invalid: width value '128x' is not an integer or 'input'
		"""
		When I do PUT request http://localhost:3000/singlepart/bad_dim
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnail spec 'bad_dim' is invalid: width value '128x' is not an integer or 'input'
		"""

	@error-reporting @413 @load
	Scenario: Too large image - uploaded image too big to fit in memory limit
		Given test-large.jpg file content as request body
		When I do PUT request http://localhost:3000/multipart/large_png,small
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' failed: image too large: cache resources exhausted
		"""
		When I do PUT request http://localhost:3000/singlepart/large_png
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'large_png' failed: image too large: cache resources exhausted
		"""

	@error-reporting @413 @thumbnail
	Scenario: Too large image - memory exhausted when thmbnailing
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/multipart/superlarge,small
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'superlarge' failed: image too large: cache resources exhausted
		"""
		When I do PUT request http://localhost:3000/singlepart/superlarge,small
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'superlarge' failed: image too large: cache resources exhausted
		"""

	@error-reporting
	Scenario: Bad URI encoding
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/filename/hello%e9world.jpg
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		invalid UTF-8 encoding in URI: "hello\\xE9world"
		"""

	@error-reporting
	Scenario: Bad URI encoding + JavaScript encode
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/filename/triple%20kro%25udfcfl.png
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		invalid UTF-8 encoding in URI: "triple kro\\xED\\xBF\\x8Fl"
		"""

	@error-reporting
	Scenario: Zero body length
		Given test.empty file content as request body
		When I do PUT request http://localhost:3000/multipart/small,tiny
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		empty body - expected image data
		"""

	@error-reporting
	Scenario: Memory limit exceeded
		When I do GET request http://localhost:3000/zero
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		memory limit exceeded
		"""

	@error-reporting @variables
	Scenario: Bad variable use - not defined
		When I do GET request http://localhost:3000/not_defined
		Then response status will be 500
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		cannot generate path 'not_defined' from template '\#{bogous}': variable 'bogous' not defined
		"""

	@error-reporting @variables
	Scenario: Bad variable use - no body
		When I do GET request http://localhost:3000/body
		Then response status will be 500
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		cannot generate path 'body' from template '#{input_digest}': need not empty request body to generate value for 'input_digest'
		"""

	@error-reporting @variables
	Scenario: Bad variable use - no image meta
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/no_image_meta
		Then response status will be 500
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		cannot generate path 'no_image_meta' from template '#{image_mime_extension}': image 'input' does not have data for variable 'image_mime_extension'
		"""
