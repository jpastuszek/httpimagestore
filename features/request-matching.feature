Feature: Request matching
	Incoming requests needs to be matched in flexible way and appropriate data needs to be available in form of variables used to parametrize processing.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		get "handler1" {
			output_text "path: '#{path}'"
		}
		"""

	@request-matching @string
	Scenario: Matching URI sections with strings
		When I do GET request http://localhost:3000/handler1/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		path: 'hello/world'
		"""

