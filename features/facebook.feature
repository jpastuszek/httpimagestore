Feature: Store limited original image in S3 and thumbnail on facebook API
	Similar API to described in https://developers.facebook.com/docs/reference/api/using-pictures/#sizes

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "original-hash"	"#{digest}"
		path "path"		"#{path}"

		get "" {
		}

		put "original" {
			thumbnail "input" "original" operation="limit" width=100 height=100 format="jpeg" quality=95

			store_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="original-hash"

			output_store_path "original"
		}

		get "&type=square" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="crop" width="50" height="50" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "&type=small" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="fit" width="50" height="2000" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "&type=normall" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="fit" width="100" height="2000" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "&type=large" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="fit" width="200" height="2000" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "&:width" "&:height" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="crop" width="#{width}" height="#{height}" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "&:width" "&:height?1080" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="fit" width="#{width}" height="#{height}" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="path"

			thumbnail "original" "thumbnail" operation="crop" width="50" height="50" format="input"

			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}
		"""
		Given httpthumbnailer server is running at http://localhost:3100/

	@facebook @type
	Scenario: Putting original to S3 bucket
		Given there is no 4006450256177f4a file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/original
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		4006450256177f4a
		"""
		Then S3 object 4006450256177f4a will contain JPEG image of size 71x100
		When I do GET request http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a
		Then response status will be 403

	@facebook @type
	Scenario: Getting square type tumbnail
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?type=square
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 50x50

	@facebook @type
	Scenario: Getting small type tumbnail
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?type=small
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 50x71

	@facebook @type
	Scenario: Getting normall type tumbnail
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?type=normall
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 100x141

	@facebook @type
	Scenario: Getting large type tumbnail
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?type=large
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 200x283

	@facebook @type
	Scenario: Getting square type tumbnail when no type is specified
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 50x50

	@facebook @size
	Scenario: Getting custom size tumbnail
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?width=123&height=321
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 123x321

	@facebook @size
	Scenario: Getting custom size tumbnail without height
		Given test.jpg file content is stored in S3 under 4006450256177f4a
		When I do GET request http://localhost:3000/4006450256177f4a?width=123
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 123x174

