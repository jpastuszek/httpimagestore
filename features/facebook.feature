Feature: Flexible API with two storage options and Facebook like thumbnailing URL format
	Features two storage apporaches: with JPEG conversion and limiting in size - for user provided content - and storing literaly.
	POST requests will end up with server side generated storage key based on input data digest.
	PUT requsts can be used to store image under provided storage key.
	Thumbnail GET API is similart to described in https://developers.facebook.com/docs/reference/api/using-pictures/#sizes.
	Stored object extension and content type is determined from image data.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "hash" "#{digest}.#{mimeextension}"
		path "path" "#{path}"

		## User uploaded content - always JPEG converted, not bigger than 2160x2160 and in hight quality compression
		post "pictures" {
			thumbnail "input" "original" operation="limit" width=2160 height=2160 format="jpeg" quality=95
			store_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="hash"
			output_store_path "original"
		}

		put "pictures" {
			thumbnail "input" "original" operation="limit" width=2160 height=2160 format="jpeg" quality=95
			store_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			output_store_path "original"
		}

		## Uploaded by us for use on the website - whatever we send
		post "images" {
			identify "input"
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="hash"
			output_store_path "input"
		}

		put "images" {
			identify "input"
			store_s3 "input" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			output_store_path "input"
		}

		## Thumbailing - keep input format; default JPEG quality is 85
		get "pictures" "&:width" "&:height" "&:operation?crop" "&:background-color?white" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&:width" "&:height?1080" "&:operation?fit" "&:background-color?white" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&:height" "&:width?1080" "&:operation?fit" "&:background-color?white" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&type=square" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="crop" width="50" height="50"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&type=small" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="fit" width="50" height="2000"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&type=normall" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="fit" width="100" height="2000"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "pictures" "&type=large" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			thumbnail "original" "thumbnail" operation="fit" width="200" height="2000"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		## By default serve original image
		get "pictures" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"
			output_image "original" cache-control="public, max-age=31557600, s-maxage=0"
		}
		"""

	@facebook @pictures @post
	Scenario: Posting picture to S3 bucket will store it under input data digest, limit to 2160x1260 and converted to JPEG
		Given there is no 625d51a1820b607f.jpg file in S3 bucket
		Given test-large.jpg file content as request body
		When I do POST request http://localhost:3000/pictures
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		625d51a1820b607f.jpg
		"""
		Then S3 object 625d51a1820b607f.jpg will contain JPEG image of size 1529x2160
		Then S3 object 625d51a1820b607f.jpg content type will be image/jpeg
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/625d51a1820b607f.jpg
		Then response status will be 403
		Given there is no b0fe25319ba5909a.jpg file in S3 bucket
		Given test.png file content as request body
		When I do POST request http://localhost:3000/pictures
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		b0fe25319ba5909a.jpg
		"""
		Then S3 object b0fe25319ba5909a.jpg will contain JPEG image of size 509x719
		Then S3 object b0fe25319ba5909a.jpg content type will be image/jpeg
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/b0fe25319ba5909a.jpg
		Then response status will be 403

	@facebook @pictures @put
	Scenario: Putting picture to S3 bucket will store it under provided path, limit it to 2160x1260 and converted to JPEG
		Given there is no hello/world file in S3 bucket
		Given test-large.jpg file content as request body
		When I do PUT request http://localhost:3000/pictures/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		hello/world
		"""
		Then S3 object hello/world will contain JPEG image of size 1529x2160
		Then S3 object hello/world content type will be image/jpeg
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/hello/world
		Then response status will be 403
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/pictures/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		hello/world
		"""
		Then S3 object hello/world will contain JPEG image of size 509x719
		Then S3 object hello/world content type will be image/jpeg
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/hello/world
		Then response status will be 403

	@facebook @images @post
	Scenario: Posting picture to S3 bucket will store it under first input data digest
		Given there is no b0fe25319ba5909a.png file in S3 bucket
		Given test.png file content as request body
		When I do POST request http://localhost:3000/images
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		b0fe25319ba5909a.png
		"""
		Then S3 object b0fe25319ba5909a.png will contain PNG image of size 509x719
		Then S3 object b0fe25319ba5909a.png content type will be image/png
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/b0fe25319ba5909a.png
		Then response status will be 403

	@facebook @images @put
	Scenario: Putting picture to S3 bucket will store it under provided path
		Given there is no hello/world file in S3 bucket
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		hello/world
		"""
		Then S3 object hello/world will contain PNG image of size 509x719
		Then S3 object hello/world content type will be image/png
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/hello/world
		Then response status will be 403

	@facebook @default
	Scenario: Getting stored image when no query string param is present
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 509x719
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/images/test.jpg
		And I do GET request http://localhost:3000/pictures/test.jpg
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 509x719

	@facebook @type
	Scenario: Getting square type tumbnail
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?type=square
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x50

	@facebook @type
	Scenario: Getting small type tumbnail
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?type=small
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x71

	@facebook @type
	Scenario: Getting normall type tumbnail
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?type=normall
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 100x141

	@facebook @type
	Scenario: Getting large type tumbnail
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?type=large
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 200x283

	@facebook @size
	Scenario: Getting custom size tumbnail
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?width=123&height=321
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 123x321

	@facebook @size
	Scenario: Getting custom size tumbnail without height
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?width=123
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 123x174

	@facebook @size
	Scenario: Getting custom size tumbnail without width
		Given test.png file content as request body
		When I do PUT request http://localhost:3000/images/test.png
		And I do GET request http://localhost:3000/pictures/test.png?height=321
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 227x321

