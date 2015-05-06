Feature: Forwarding of transaction ID header to thumbnailer
	HTTP Image Store should forward transaction ID header found in the request to HTTP Thumbnailer

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		post "identify" {
			identify "input"
		}

		post "single" {
			thumbnail "input" "thumbnail" operation="pad" width="8" height="8"
		}

		post "multi" {
			thumbnail "input" {
				"small"             operation="crop"        width=128       height=128      format="jpeg"
				"tiny_png"          operation="crop"        width=32        height=32       format="png"
			}
		}
		"""

	@xid-forwarding
	Scenario: Should forward XID with identify requests
		Given tiny.png file content as request body
		And XID header set to 123
		When I do POST request http://localhost:3000/identify
		Then response status will be 200
		And httpimagestore log will contain "xid":"123"
		And httpthumbnailer log will contain "xid":"123"

	@xid-forwarding
	Scenario: Should forward XID with single thumbnail requests
		Given tiny.png file content as request body
		And XID header set to 123
		When I do POST request http://localhost:3000/single
		Then response status will be 200
		And httpimagestore log will contain "xid":"123"
		And httpthumbnailer log will contain "xid":"123"

	@xid-forwarding
	Scenario: Should forward XID with multi thumbnail requests
		Given tiny.png file content as request body
		And XID header set to 123
		When I do POST request http://localhost:3000/multi
		Then response status will be 200
		And httpimagestore log will contain "xid":"123"
		And httpthumbnailer log will contain "xid":"123"
