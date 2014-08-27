Feature: Rewrite of the output path and URL
	Output path or URL can be rewritten with variables to customise further the API output.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		path "input_digest"       "#{input_digest}"
		path "rewritten"          "hello/#{prefix}/#{input_sha256}.jpg"
		path "rewritten-absolute" "/hello/#{prefix}/#{input_sha256}.jpg"
		path "demo"               "image/#{input_sha256}.jpg"

		post "rewrite" "path" "&:prefix" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_path "input" path="rewritten"
		}

		post "rewrite" "uri" "path" "&:prefix" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_uri "input" path="rewritten"
		}

		post "rewrite" "uri" "path-absolute" "&:prefix" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_uri "input" path="rewritten-absolute"
		}

		post "rewrite" "url" "path" "&:prefix" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" path="rewritten"
		}

		post "rewrite" "url" "path-absolute" "&:prefix" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" path="rewritten-absolute"
		}

		post "rewrite" "url" "scheme" "&:proto" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" scheme="#{proto}"
		}

		post "rewrite" "url" "host" "&:target" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" host="www.#{target}"
		}

		post "rewrite" "url" "port" "&:number" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" port="#{number}"
		}

		post "rewrite" "demo" {
			store_file "input" root="/tmp" path="input_digest"
			output_store_url "input" scheme="ftp" host="example.com" port="421" path="demo"
		}
		"""

	Scenario: Store path rewriting
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/path?prefix=world
		And response body will be CRLF ended lines
		"""
		hello/world/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

	Scenario: Store URI path rewriting
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/uri/path?prefix=world
		And response body will be CRLF ended lines
		"""
		/hello/world/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

	Scenario: Store URI path rewriting - absolute path
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/uri/path-absolute?prefix=world
		And response body will be CRLF ended lines
		"""
		/hello/world/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

	Scenario: Store URL path rewriting
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/url/path?prefix=world
		And response body will be CRLF ended lines
		"""
		file:/hello/world/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

	Scenario: Store URL path rewriting - absolute path
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/url/path-absolute?prefix=world
		And response body will be CRLF ended lines
		"""
		file:/hello/world/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

	Scenario: Store URL scheme rewriting
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/url/host?target=example.com
		And response body will be CRLF ended lines
		"""
		file://www.example.com/b0fe25319ba5909a
		"""

	Scenario: Store URL port rewriting
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/url/port?number=41
		And response body will be CRLF ended lines
		"""
		file://localhost:41/b0fe25319ba5909a
		"""

	Scenario: Store URL rewriting demo
		Given test.png file content as request body
		When I do POST request http://localhost:3000/rewrite/demo
		And response body will be CRLF ended lines
		"""
		ftp://example.com:421/image/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e.jpg
		"""

