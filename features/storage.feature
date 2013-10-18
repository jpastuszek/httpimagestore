Feature: Storing images under different names
	Storage supports UUID and SHA digest based auto generated storage as well as user provided via request or static configuration string.


	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		path "input_digest"     "#{input_digest}"
		path "input_sha256"     "#{input_sha256}"
		path "image_digest"     "#{image_digest}"
		path "image_sha256"     "#{image_sha256}"
		path "uuid"             "#{uuid}"
		path "image_meta"       "#{image_width}x#{image_height}.#{image_mime_extension}"
		path "input_image_meta" "#{input_image_width}x#{input_image_height}.#{input_image_mime_extension}"

		post "images" "input_digest" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="50"
			store_file "thumbnail" root="/tmp" path="input_digest"
			output_store_path "thumbnail"
		}

		post "images" "input_sha256" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="50"
			store_file "thumbnail" root="/tmp" path="input_sha256"
			output_store_path "thumbnail"
		}

		post "images" "image_digest" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="50"
			store_file "thumbnail" root="/tmp" path="image_digest"
			output_store_path "thumbnail"
		}

		post "images" "image_sha256" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="50"
			store_file "thumbnail" root="/tmp" path="image_sha256"
			output_store_path "thumbnail"
		}

		post "images" "uuid" {
			store_file "input" root="/tmp" path="uuid"
			output_store_path "input"
		}

		post "images" "image_meta" "identify" {
			identify "input"
			store_file "input" root="/tmp" path="image_meta"
			output_store_path "input"
		}

		post "images" "image_meta" "thumbnail" "input" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="100"
			store_file "input" root="/tmp" path="image_meta"
			output_store_path "input"
		}

		post "images" "image_meta" "thumbnails" "input" {
			thumbnail "input" {
				"thumbnail" operation="crop" width="50" height="100"
			}

			store_file "input" root="/tmp" path="image_meta"
			output_store_path "input"
		}

		post "images" "image_meta" "thumbnail" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="100"
			store_file "thumbnail" root="/tmp" path="image_meta"
			output_store_path "thumbnail"
		}

		post "images" "image_meta" "thumbnails" {
			thumbnail "input" {
				"thumbnail" operation="crop" width="50" height="100"
			}
			store_file "thumbnail" root="/tmp" path="image_meta"
			output_store_path "thumbnail"
		}

		post "images" "input_image_meta" "thumbnail" {
			thumbnail "input" "thumbnail" operation="crop" width="50" height="100"
			store_file "thumbnail" root="/tmp" path="input_image_meta"
			output_store_path "thumbnail"
		}
		"""

		@storage @input_digest
		Scenario: Posting picture to file system under input data digest
		Given there is no file /tmp/b0fe25319ba5909a
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/input_digest
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			b0fe25319ba5909a
			"""
			Then file /tmp/b0fe25319ba5909a will contain PNG image of size 50x50

		@storage @input_sha256
		Scenario: Posting picture to file system under input data digest
			Given there is no file /tmp/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/input_sha256
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e
			"""
			Then file /tmp/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e will contain PNG image of size 50x50

		@storage @image_digest
		Scenario: Posting picture to file system under input data digest
		Given there is no file /tmp/b0fe25319ba5909a
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/image_digest
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			091000e2c0aee836
			"""
			Then file /tmp/091000e2c0aee836 will contain PNG image of size 50x50

		@storage @image_sha256
		Scenario: Posting picture to file system under input data digest
			Given there is no file /tmp/b0fe25319ba5909aa97fded546847a96d7fdf26e18715b0cfccfcbee52dce57e
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/image_sha256
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			091000e2c0aee836fff432c1151faba86d46690c900c0f6355247a353defa37f
			"""
			Then file /tmp/091000e2c0aee836fff432c1151faba86d46690c900c0f6355247a353defa37f will contain PNG image of size 50x50

		@storage @uuid
		Scenario: Posting picture to file system under input data digest
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/uuid
			Then response status will be 200
			And response content type will be text/plain
			And response body will contain UUID

		@storage @image_meta @identify
		Scenario: Posting picture to file system under input data digest
			Given there is no file /tmp/509x719.png
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/image_meta/identify
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			509x719.png
			"""
			Then file /tmp/509x719.png will contain PNG image of size 509x719

		@storage @image_meta @thumbnail
		Scenario: Posting picture to file system under input data digest
			Given test.png file content as request body
			Given there is no file /tmp/50x100.png
			When I do POST request http://localhost:3000/images/image_meta/thumbnail
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			50x100.png
			"""
			Then file /tmp/50x100.png will contain PNG image of size 50x100

		@storage @image_meta @thumbnails
		Scenario: Posting picture to file system under input data digest
			Given test.png file content as request body
			Given there is no file /tmp/50x100.png
			When I do POST request http://localhost:3000/images/image_meta/thumbnails
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			50x100.png
			"""
			Then file /tmp/50x100.png will contain PNG image of size 50x100

		@storage @input_image_meta
		Scenario: Input image meta variables
			Given there is no file /tmp/509x719.png
			Given test.png file content as request body
			When I do POST request http://localhost:3000/images/input_image_meta/thumbnail
			Then response status will be 200
			And response content type will be text/plain
			And response body will be CRLF ended lines
			"""
			509x719.png
			"""
			Then file /tmp/509x719.png will contain PNG image of size 50x100
