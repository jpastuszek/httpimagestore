Feature: Data URI style image output
	HTTP Image Store can provide images base64 encoded in data URI format so they can be included directly in HTML pages.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		post "data-uri" "no-identify" {
			output_data_uri_image "input"
		}

		post "data-uri" "cache-control" {
			identify "input"
			output_data_uri_image "input" cache-control="public, max-age=31557600, s-maxage=0"
		}

		post "data-uri" {
			identify "input"
			output_data_uri_image "input"
		}
		"""

	@data-uri
	Scenario: Getting image encoded in data URI scheme with base64 encoding
		Given tiny.png file content as request body
		When I do POST request http://localhost:3000/data-uri
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be
		"""
		data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAgUlEQVQI10XNsQ2CUBhF4XOTfwJeog0U2kLJNlZOxQ4swBLGwkhhY6MNRkic4Fq8ENqTLznqhuvlOY2v5f6egaYs6iq1x30YAENdJskgEBAYUFMlYSMw2CYk2sMOkTFgI6Fp/mEpt7Ua69Sf2TRgLESMt8dW5bwE4vtZvOK8xkj8Ac8BL8dFQipPAAAAAElFTkSuQmCC
		"""

	@data-uri
	Scenario: Getting image encoded in data URI scheme with base64 encoding - cache-control should be supported
		Given tiny.png file content as request body
		When I do POST request http://localhost:3000/data-uri/cache-control
		Then response status will be 200
		And response content type will be text/uri-list
		And response Cache-Control will be public, max-age=31557600, s-maxage=0
		And response body will be
		"""
		data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAgUlEQVQI10XNsQ2CUBhF4XOTfwJeog0U2kLJNlZOxQ4swBLGwkhhY6MNRkic4Fq8ENqTLznqhuvlOY2v5f6egaYs6iq1x30YAENdJskgEBAYUFMlYSMw2CYk2sMOkTFgI6Fp/mEpt7Ua69Sf2TRgLESMt8dW5bwE4vtZvOK8xkj8Ac8BL8dFQipPAAAAAElFTkSuQmCC
		"""

	@data-uri
	Scenario: Error 500 served when data URI output is used on unidentified image
		Given tiny.png file content as request body
		When I do POST request http://localhost:3000/data-uri/no-identify
		Then response status will be 500
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		image 'input' needs to be identified first to be used in data URI output
		"""
