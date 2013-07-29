Feature: Store limited original image in S3 and thumbnail based on request
	Posted image will be converted to JPEG and resized if it is bigger that given dimensions.
	Than it will get stored on S3.
	Get interface will allow to fetch the image from S3 and thumbnailing to given parameters.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "original-hash"	"#{digest}.#{mimeextension}"
		path "path"		"#{path}"

		put "original" {
			thumbnail "input" "original" operation="limit" width=100 height=100 format="jpeg" quality=95

			store_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="original-hash"

			output_store_path "original"
		}

		get "thumbnail" "v1" ":path" ":operation" ":width" ":height" ":options?" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="png"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "thumbnail" "v2" ":operation" ":width" ":height" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="#{query_string_options}" quality=84 format="png"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}
		"""

	@s3-store-and-thumbnail
	Scenario: Putting original to S3 bucket
		Given there is no 4006450256177f4a.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/original
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		4006450256177f4a.jpg
		"""
		Then S3 object 4006450256177f4a.jpg will contain JPEG image of size 71x100
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a.jpg
		Then response status will be 403

	@s3-store-and-thumbnail
	Scenario: Getting thumbnail to spec based on uploaded S3 image
		Given test.jpg file content is stored in S3 under 4006450256177f4a.jpg
		When I do GET request http://localhost:3000/thumbnail/v1/4006450256177f4a.jpg/pad/50/50
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x50

	@s3-store-and-thumbnail
	Scenario: Getting thumbnail to spec based on uploaded S3 image - with options passed
		Given test.jpg file content is stored in S3 under 4006450256177f4a.jpg
		When I do GET request http://localhost:3000/thumbnail/v1/4006450256177f4a.jpg/pad/50/50/background-color:green
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x50
		And that image pixel at 2x2 should be of color green

	@s3-store-and-thumbnail @v2
	Scenario: Getting thumbnail to spec based on uploaded S3 image - v2
		Given test.jpg file content is stored in S3 under 4006450256177f4a.jpg
		When I do GET request http://localhost:3000/thumbnail/v2/pad/50/50/4006450256177f4a.jpg
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x50

	@s3-store-and-thumbnail @v2
	Scenario: Getting thumbnail to spec based on uploaded S3 image - with options passed
		Given test.jpg file content is stored in S3 under 4006450256177f4a.jpg
		When I do GET request http://localhost:3000/thumbnail/v2/pad/50/50/4006450256177f4a.jpg?background-color=green
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 50x50
		And that image pixel at 2x2 should be of color green

