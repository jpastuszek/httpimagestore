Feature: Validating URI HMAC
	To authenticate URIs a varification step can be added to configuration that will varify HMAC token passed as query string parameter. Only URIs with valid token will be processed. HMAC will only be valid if same secret key was used to generate it.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		get "hello" "&:bar?" "&:hmac?" "&:foo?" {
			validate_hmac "#{hmac}" secret="pass123" exclude="hmac" remove="hmac,nonce"
			output_text "valid"
		}

		post "test" "&:hmac?" {
			validate_hmac "#{hmac}" secret="pass123" exclude="hmac"
			thumbnail "input" "thumbnail" operation="limit" width=100 height=100 format="jpeg" options="#{query_string_options}"
			output_image "thumbnail"
		}

		get "fake" "&:bar?" "&:hmac?" "&:request_uri?" {
			validate_hmac "#{hmac}" secret="pass123" exclude="hmac" remove="hmac,nonce"
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
		valid
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
	Scenario: Properly authenticated URI with improved security
		When I do GET request http://localhost:3000/hello?nonce=1cebbd063f8091be&hmac=d9393ab46832b74fa2fd50667afbd02d6c57a7ec
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		valid
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

