Feature: Validating URI HMAC
	To authenticate URIs a varification step can be added to configuration that will varify HMAC token passed as query string parameter. Only URIs with valid token will be processed. HMAC will only be valid if same secret key was used to generate it.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		get "hello" {
			validate_uri_hmac "hmac" secret="pass123" exclude="baz" remove="hmac,nonce"
			output_text "valid qs: '#{query_string_options}'"
		}

		post "test" {
			validate_uri_hmac "hmac" secret="pass123"
			thumbnail "input" "thumbnail" operation="limit" width=100 height=100 format="jpeg" options="#{query_string_options}"
			output_image "thumbnail"
		}

		get "fake" "&:request_uri?" {
			validate_uri_hmac "hmac" secret="pass123" remove="hmac,nonce"
			output_text "valid"
		}

		get "conditional" "&:hmac?" {
			validate_uri_hmac "hmac" secret="pass123" if-variable-matches="hmac"
			output_text "valid"
		}

		get "header" {
			validate_header_hmac "X-Forwarded-URI" "hmac" secret="pass123"
			output_text "valid"
		}

		get "lockpicks" {
			validate_header_hmac "X-Forwarded-URI" "hmac" secret="pass123" lockpicks="foo,bar"
			output_text "valid"
		}
		"""

	@validate-hmac
	Scenario: Properly authenticated URI
		When I do GET request http://localhost:3000/hello?hmac=cc67210148307affa1465ee5d146978b1f3278cb
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid qs: ''
		"""

	@validate-hmac
	Scenario: Properly authenticated URI with excluded query stirng parameter
		When I do GET request http://localhost:3000/hello?baz=1&hmac=cc67210148307affa1465ee5d146978b1f3278cb
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid qs: 'baz:1'
		"""
		When I do GET request http://localhost:3000/hello?baz=42&hmac=cc67210148307affa1465ee5d146978b1f3278cb
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid qs: 'baz:42'
		"""

	@validate-hmac
	Scenario: Properly authenticated URI with extra query stirng parameter
		When I do GET request http://localhost:3000/hello?foo=bar&hmac=d1aad080f8e744d6e60536b30a87d8ac2f76cb02
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid qs: 'foo:bar'
		"""

	@validate-hmac
	Scenario: Invalid HMAC URI
		When I do GET request http://localhost:3000/hello?hmac=0067210148307affa1465ee5d146978b1f3278cb
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: provided HMAC '0067210148307affa1465ee5d146978b1f3278cb' for URI '/hello' is not valid
		"""

	@validate-hmac
	Scenario: Missing HMAC URI
		When I do GET request http://localhost:3000/hello
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: HMAC query string parameter 'hmac' not found
		"""
		When I do GET request http://localhost:3000/hello?hmac=
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: provided HMAC '' for URI '/hello' is not valid
		"""

	@validate-hmac
	Scenario: Properly authenticated URI with improved security
		When I do GET request http://localhost:3000/hello?nonce=1cebbd063f8091be&hmac=d9393ab46832b74fa2fd50667afbd02d6c57a7ec
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid qs: ''
		"""

	@validate-hmac @fake
	Scenario: Tring to fake request_uri
		When I do GET request http://localhost:3000/fake?request_uri=/blah&hmac=9857a4e8b182e4daac444e1c90613a220930ca6e
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: provided HMAC '9857a4e8b182e4daac444e1c90613a220930ca6e' for URI '/fake?request_uri=%2Fblah' is not valid
		"""

	@validate-hmac @thumbnailing
	Scenario: Properly authenticate URI with thumbnailing
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/test?hmac=55eee34055a89648101cbb3d88c9af560078920d
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 71x100

	@validate-hmac @condition
	Scenario: Properly authenticated URI with improved security
		When I do GET request http://localhost:3000/conditional
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/conditional?hmac=28d8a485111af7f6a68791f3afabe55d7b0ac63d
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/conditional?hmac=00d8a485111af7f6a68791f3afabe55d7b0ac63d
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: provided HMAC '00d8a485111af7f6a68791f3afabe55d7b0ac63d' for URI '/conditional' is not valid
		"""

	@validate-hmac @header
	Scenario: Properly authenticated URI via header
		Given X-FORWARDED-URI header set to /hello
		When I do GET request http://localhost:3000/header?hmac=cc67210148307affa1465ee5d146978b1f3278cb
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""

	@validate-hmac @header
	Scenario: Missing header for URI authentication
		When I do GET request http://localhost:3000/header?hmac=cc67210148307affa1465ee5d146978b1f3278cb
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: header 'X-FORWARDED-URI' not found in request body for HMAC verificaton
		"""

	@validate-hmac @header @lockpicks
	Scenario: Bypassing validation with lockpick HMAC
		Given X-FORWARDED-URI header set to /lockpicks
		When I do GET request http://localhost:3000/lockpicks?hmac=a4c3fe2c9856f5df6412a04a3be877487f61d7d2
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/lockpicks?hmac=foo
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/lockpicks?hmac=bar
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/lockpicks?hmac=baz
		Then response status will be 403
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HMAC URI authentication with digest 'sha1' failed: provided HMAC 'baz' for URI '/lockpicks' is not valid
		"""

	@validate-hmac @header @lockpicks
	Scenario: Bypassing validation with lockpick HMAC also skips header lookup
		When I do GET request http://localhost:3000/lockpicks?hmac=foo
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""
		When I do GET request http://localhost:3000/lockpicks?hmac=bar&baz=xyz
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
		"""

