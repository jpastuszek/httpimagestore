Feature: Image list based thumbnailing and S3 storage
	Storage based on URL specified image names to be generated and stored using two different path formats.
	This configuration should be mostly compatible with pre v1.0 release.

	Background:
		Given S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		s3 key="@AWS_ACCESS_KEY_ID@" secret="@AWS_SECRET_ACCESS_KEY@" ssl=false

		path "hash"             "#{input_digest}.#{image_mime_extension}"
		path "hash-name"        "#{input_digest}/#{image_name}.#{image_mime_extension}"
		path "structured"       "#{dirname}/#{input_digest}/#{basename}.#{image_mime_extension}"
		path "structured-name"  "#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{image_mime_extension}"
		path "flexi-original"   "#{hash}.jpg"

		put "thumbnail" ":name_list" ":path/.+/" {
			thumbnail "input" {
				"small"             operation="crop"        width=128       height=128      format="jpeg"           if-image-name-on="#{name_list}"
				"tiny_png"          operation="crop"        width=32        height=32       format="png"            if-image-name-on="#{name_list}"
				"bad"               operation="crop"        width=0         height=0                                if-image-name-on="#{name_list}"
			}

			store_s3 "input"     bucket="@AWS_S3_TEST_BUCKET@"   path="structured"       public=true
			store_s3 "small"     bucket="@AWS_S3_TEST_BUCKET@"   path="structured-name"  public=true if-image-name-on="#{name_list}"
			store_s3 "tiny_png"  bucket="@AWS_S3_TEST_BUCKET@"   path="structured-name"  public=true if-image-name-on="#{name_list}"

			output_store_url {
				"input"
				"small"             if-image-name-on="#{name_list}"
				"tiny_png"          if-image-name-on="#{name_list}"
			}
		}

		put "thumbnail" ":name_list" {
			thumbnail "input" {
				"small"             operation="crop"        width=128       height=128      format="jpeg"   if-image-name-on="#{name_list}"
				"tiny_png"          operation="crop"        width=32        height=32       format="png"    if-image-name-on="#{name_list}"
			}

			store_s3 "input"     bucket="@AWS_S3_TEST_BUCKET@"   path="hash"      public=true
			store_s3 "small"     bucket="@AWS_S3_TEST_BUCKET@"   path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "tiny_png"  bucket="@AWS_S3_TEST_BUCKET@"   path="hash-name" public=true if-image-name-on="#{name_list}"

			output_store_url {
				"input"
				"small"             if-image-name-on="#{name_list}"
				"tiny_png"          if-image-name-on="#{name_list}"
				"bad"               if-image-name-on="#{name_list}"
			}
		}

		# Forward compatible getting of thumbnails
		get "thumbnail" ":hash/[0-f]{16}/" ":type/.*-square.jpg/" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="flexi-original"
			thumbnail "original" "thumbnail" operation="crop" width="50" height="50"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}

		get "thumbnail" ":hash/[0-f]{16}/" ":type/.*-normal.jpg/" {
			source_s3 "original" bucket="@AWS_S3_TEST_BUCKET@" path="flexi-original"
			thumbnail "original" "thumbnail" operation="fit" width="100" height="2000"
			output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
		}
		"""

	@compatibility
	Scenario: Putting original and its thumbnails to S3 bucket
		Given there is no 4006450256177f4a.jpg file in S3 bucket
		And there is no 4006450256177f4a/small.jpg file in S3 bucket
		And there is no 4006450256177f4a/tiny_png.png file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny_png
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/small.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/tiny_png.png
		"""
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a.jpg will contain JPEG image of size 509x719
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a.jpg content type will be image/jpeg
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/small.jpg will contain JPEG image of size 128x128
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/small.jpg content type will be image/jpeg
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/tiny_png.png will contain PNG image of size 32x32
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/4006450256177f4a/tiny_png.png content type will be image/png

	@compatibility
	Scenario: Putting original and its thumbnails to S3 bucket under custom path
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny_png.png file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny_png/test/image/test
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg will contain JPEG image of size 509x719
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg will contain JPEG image of size 128x128
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg content type will be image/jpeg
		Then http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png will contain PNG image of size 32x32
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	@compatibility
	Scenario: Input file extension should be based on content detected mime type and not on provided path
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny_png.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/tiny_png/test/image/test.gif
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		And http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	@compatibility
	Scenario: Custom path name encoding when UTF-8 characters can be used
		Given there is no test/图像/4006450256177f4a/测试.jpg file in S3 bucket
		And there is no test/图像/4006450256177f4a/测试-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request with encoded URL http://localhost:3000/thumbnail/small/test/图像/测试
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95.jpg
		http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95-small.jpg
		"""
		And Encoded URL http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/图像/4006450256177f4a/测试.jpg will contain JPEG image of size 509x719
		And Encoded URL http://@AWS_S3_TEST_BUCKET@.s3.amazonaws.com/test/图像/4006450256177f4a/测试-small.jpg will contain JPEG image of size 128x128

	@compatibility @forward @test
	Scenario: Getting thumbanils requested with compatibility API from flexi bucket
			Given test.jpg file content is stored in S3 under 1234567890123456.jpg
		When I do GET request http://localhost:3000/thumbnail/1234567890123456/foobar-blah-square.jpg
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 50x50
		When I do GET request http://localhost:3000/thumbnail/1234567890123456/foobar-blah-normal.jpg
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 100x141
