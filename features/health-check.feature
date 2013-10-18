Feature: Health check URL
	Server can be tested with GET request to '/health_check'.

	Background:
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		"""

	@health-check
	Scenario: Passing health check when thumbnailer is running
		Given httpthumbnailer server is running at http://localhost:3100/
		When I do GET request http://localhost:3000/health_check
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		HTTP Image Store OK
		"""

	@health-check
	Scenario: Failing health check when thumbnailer is not running
		Given httpthumbnailer server is not running
		When I do GET request http://localhost:3000/health_check
		Then response status will be 502
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		Connection refused - connect(2) (http://localhost:3100)
		"""