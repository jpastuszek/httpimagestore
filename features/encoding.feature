Feature: Encoded UTF-8 URI support
	HTTP Image Store should be able to decode UTF-8 characters form URI using URI decode and also support JavaScript encode() format.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		path "path"             "#{path}"

		post "encoding" "encoded" {
			store_file "input" root="/tmp" path="path"
			output_store_uri "input" path="path"
		}

		post "encoding" "decoded" {
			store_file "input" root="/tmp" path="path"
			output_store_path "input" path="path"
		}
		"""

	Scenario: JavaScript encode() + URL encoded variable decoding and URL encoding
		Given test.png file content as request body
		When I do POST request http://localhost:3000/encoding/encoded/triple%20kro%25u0301l.png
		And response body will be CRLF ended lines
		"""
		/triple%20kro%CC%81l.png
		"""

	Scenario: URL encoded variable decoding
		Given test.png file content as request body
		When I do POST request http://localhost:3000/encoding/decoded/triple%20kr%C3%B3l.png
		And response body will be CRLF ended lines
		"""
		triple król.png
		"""
