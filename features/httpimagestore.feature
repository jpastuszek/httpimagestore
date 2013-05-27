Feature: Storing of original image and specified classes of its thumbnails on S3
	In order to store original image and its thumbnails in preconfigured S3 bucket
	A user must PUT the image data to URI representing its path within the bucket
	The response will be paths to files stored in S3

	Background:
		Given httpimagestoretest S3 bucket with key AKIAJMUYVYOSACNXLPTQ and secret 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
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3 key="AKIAJMUYVYOSACNXLPTQ" secret="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" ssl=false

		path "hash"		"#{digest}.#{mimeextension}"
		path "hash-name"	"#{digest}/#{imagename}.#{mimeextension}"
		path "structured"	"#{dirname}/#{digest}/#{basename}.#{mimeextension}"
		path "structured-name"	"#{dirname}/#{digest}/#{basename}-#{imagename}.#{mimeextension}"

		put "thumbnail" ":name_list" ":path/.+/" {
			thumbnail "input" {
				"original"	operation="limit"	width=1080	height=1080	format="jpeg"		quality=95
				"small"		operation="crop"	width=128	height=128	format="jpeg"		if-image-name-on="#{name_list}"
				"tiny"		operation="crop"	width=32	height=32				if-image-name-on="#{name_list}"
				"tiny_png"	operation="crop"	width=32	height=32	format="png"		if-image-name-on="#{name_list}"
				"bad"		operation="crop"	width=0		height=0				if-image-name-on="#{name_list}"
				"superlarge"	operation="crop"	width=16000	height=16000				if-image-name-on="#{name_list}"
				"large_png"	operation="crop"	width=7000	height=7000	format="png"		if-image-name-on="#{name_list}"
			}

			store_s3 "original"	bucket="httpimagestoretest-originals"	path="hash"
			store_s3 "input"	bucket="httpimagestoretest"		path="structured"	public=true
			store_s3 "small"	bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"
			store_s3 "tiny"		bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"
			store_s3 "tiny_png"	bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"
			store_s3 "bad"		bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"
			store_s3 "superlarge"	bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"
			store_s3 "large_png"	bucket="httpimagestoretest"		path="structured-name"	public=true if-image-name-on="#{name_list}"

			output_store_url {
				"input"
				"small"		if-image-name-on="#{name_list}"
				"tiny"		if-image-name-on="#{name_list}"
				"tiny_png"	if-image-name-on="#{name_list}"
				"bad"		if-image-name-on="#{name_list}"
				"superlarge"	if-image-name-on="#{name_list}"
				"large_png"	if-image-name-on="#{name_list}"
			}
		}

		put "thumbnail" ":name_list" {
			thumbnail "input" {
				"original"	operation="limit"	width=1080	height=1080	format="jpeg"	quality=95
				"small"		operation="crop"	width=128	height=128	format="jpeg"	if-image-name-on="#{name_list}"
				"tiny"		operation="crop"	width=32	height=32			if-image-name-on="#{name_list}"
				"tiny_png"	operation="crop"	width=32	height=32	format="png"	if-image-name-on="#{name_list}"
				"bad"		operation="crop"	width=0		height=0			if-image-name-on="#{name_list}"
				"superlarge"	operation="crop"	width=16000	height=16000			if-image-name-on="#{name_list}"
				"large_png"	operation="crop"	width=7000	height=7000	format="png"	if-image-name-on="#{name_list}"
			}

			store_s3 "original"	bucket="httpimagestoretest-originals"	path="hash"
			store_s3 "input"	bucket="httpimagestoretest"		path="hash"	 public=true
			store_s3 "small"	bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "tiny"		bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "tiny_png"	bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "bad"		bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "superlarge"	bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"
			store_s3 "large_png"	bucket="httpimagestoretest"		path="hash-name" public=true if-image-name-on="#{name_list}"

			output_store_url {
				"input"
				"small"		if-image-name-on="#{name_list}"
				"tiny"		if-image-name-on="#{name_list}"
				"tiny_png"	if-image-name-on="#{name_list}"
				"bad"		if-image-name-on="#{name_list}"
				"superlarge"	if-image-name-on="#{name_list}"
				"large_png"	if-image-name-on="#{name_list}"
			}
		}
		"""
		Given httpthumbnailer server is running at http://localhost:3100/

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
		http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a.jpg
		http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/small.jpg
		http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/tiny_png.png
		"""
		Then http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a.jpg will contain JPEG image of size 509x719
		And http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a.jpg content type will be image/jpeg
		Then http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/small.jpg will contain JPEG image of size 128x128
		And http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/small.jpg content type will be image/jpeg
		Then http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/tiny_png.png will contain PNG image of size 32x32
		And http://httpimagestoretest.s3.amazonaws.com/4006450256177f4a/tiny_png.png content type will be image/png

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
		http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		Then http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg will contain JPEG image of size 509x719
		And http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		Then http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg will contain JPEG image of size 128x128
		And http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg content type will be image/jpeg
		Then http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png will contain PNG image of size 32x32
		And http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	Scenario: Input file extension should be based on content detected mime type and not on provided path
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny_png.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/tiny_png/test/image/test.gif
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		And http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		And http://httpimagestoretest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	Scenario: Custom path name encoding when UTF-8 characters can be used
		Given there is no test/图像/4006450256177f4a/测试.jpg file in S3 bucket
		And there is no test/图像/4006450256177f4a/测试-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/图像/测试
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://httpimagestoretest.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95.jpg
		http://httpimagestoretest.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95-small.jpg
		"""
		And http://httpimagestoretest.s3.amazonaws.com/test/图像/4006450256177f4a/测试.jpg will contain JPEG image of size 509x719
		And http://httpimagestoretest.s3.amazonaws.com/test/图像/4006450256177f4a/测试-small.jpg will contain JPEG image of size 128x128

	Scenario: Reporting of missing resource
		When I do GET request http://localhost:3000/blah
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		request for URI '/blah' was not handled by the server
		"""

	Scenario: Reporting of unsupported media type
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny.jpg file in S3 bucket
		Given test.txt file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny/test/image/test.jpg
		Then response status will be 415
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		unsupported media type: no decode delegate for this image format
		"""
		And S3 bucket will not contain test/image/4006450256177f4a/test.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-small.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-tiny.jpg

	Scenario: Reporting and handling of thumbnailing errors
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-small.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny,bad/test/image/test.jpg
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'bad' failed: at least one image dimension is zero: 0x0
		"""
		And S3 bucket will not contain test/image/4006450256177f4a/test.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-small.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-tiny.jpg

	Scenario: Too large image - uploaded image too big to fit in memory limit
		Given test-large.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/large_png/test/image/test.jpg
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		image too large: cache resources exhausted
		"""

	Scenario: Too large image - memory exhausted when thmbnailing
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/superlarge/test/image/test.jpg
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		thumbnailing of 'input' into 'superlarge' failed: image too large: cache resources exhausted
		"""

	Scenario: Zero body length
		Given test.empty file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/image/test.jpg
		Then response status will be 400
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		empty body - expected image data
		"""

