Feature: Storing of original image and specified classes of its thumbnails on S3
	In order to store original image and its thumbnails in preconfigured S3 bucket
	A user must PUT the image data to URI representing its path within the bucket
	The response will be paths to files stored in S3

	Background:
		Given httpimagestore log is empty
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		thumbnail_class 'tiny', 'crop', 32, 32
		thumbnail_class 'tiny_png', 'crop', 32, 32, 'PNG'
		thumbnail_class 'bad', 'crop', 0, 0
		thumbnail_class 'superlarge', 'crop', 16000, 16000
		thumbnail_class 'large_png', 'crop', 7000, 7000, 'PNG'
		"""
		Given httpthumbnailer log is empty
		Given httpthumbnailer server is running at http://localhost:3100/
		Given issthumbtest S3 bucket with key AKIAJMUYVYOSACNXLPTQ and secret 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

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
		http://issthumbtest.s3.amazonaws.com/4006450256177f4a.jpg
		http://issthumbtest.s3.amazonaws.com/4006450256177f4a/small.jpg
		http://issthumbtest.s3.amazonaws.com/4006450256177f4a/tiny_png.png
		"""
		Then http://issthumbtest.s3.amazonaws.com/4006450256177f4a.jpg will contain JPEG image of size 509x719
		And http://issthumbtest.s3.amazonaws.com/4006450256177f4a.jpg content type will be image/jpeg
		Then http://issthumbtest.s3.amazonaws.com/4006450256177f4a/small.jpg will contain JPEG image of size 128x128
		And http://issthumbtest.s3.amazonaws.com/4006450256177f4a/small.jpg content type will be image/jpeg
		Then http://issthumbtest.s3.amazonaws.com/4006450256177f4a/tiny_png.png will contain PNG image of size 32x32
		And http://issthumbtest.s3.amazonaws.com/4006450256177f4a/tiny_png.png content type will be image/png

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
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		Then http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg will contain JPEG image of size 509x719
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		Then http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg will contain JPEG image of size 128x128
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg content type will be image/jpeg
		Then http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png will contain PNG image of size 32x32
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	Scenario: Custom path name can contain file name extension that may be used as failback to content based detection
		Given there is no test/image/4006450256177f4a/test.jpg file in S3 bucket
		And there is no test/image/4006450256177f4a/test-tiny_png.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/tiny_png/test/image/test.jpg
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg content type will be image/jpeg
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny_png.png content type will be image/png

	Scenario: Custom path name encoding when UTF-8 characters can be used
		Given there is no test/图像/4006450256177f4a/测试.jpg file in S3 bucket
		And there is no test/图像/4006450256177f4a/测试-small.jpg file in S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small/test/图像/测试
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF ended lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95.jpg
		http://issthumbtest.s3.amazonaws.com/test/%E5%9B%BE%E5%83%8F/4006450256177f4a/%E6%B5%8B%E8%AF%95-small.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/图像/4006450256177f4a/测试.jpg will contain JPEG image of size 509x719
		And http://issthumbtest.s3.amazonaws.com/test/图像/4006450256177f4a/测试-small.jpg will contain JPEG image of size 128x128

	Scenario: Reporting of missing resource
		When I do GET request http://localhost:3000/blah
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		Resource '/blah' not found
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
		Error: HTTPThumbnailerClient::UnsupportedMediaTypeError:
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
		Then response status will be 500
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		Error: ThumbnailingError: Thumbnailing for class 'bad' failed: Error: ArgumentError:
		"""
		And S3 bucket will not contain test/image/4006450256177f4a/test.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-small.jpg
		And S3 bucket will not contain test/image/4006450256177f4a/test-tiny.jpg

	Scenario: Reporting of missing class error
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,bogous,bad/test/image/test.jpg
		Then response status will be 404
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		Error: Configuration::ThumbnailClassDoesNotExistError: Class 'bogous' does not exist
		"""

	Scenario: Too large image - uploaded image too big to fit in memory limit
		Given test-large.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/large_png/test/image/test.jpg
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		Error: HTTPThumbnailerClient::ImageTooLargeError:
		"""

	Scenario: Too large image - memory exhausted when thmbnailing
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/superlarge/test/image/test.jpg
		Then response status will be 413
		And response content type will be text/plain
		And response body will be CRLF ended lines like
		"""
		Error: ThumbnailingError: Thumbnailing for class 'superlarge' failed: Error: Thumbnailer::ImageTooLargeError:
		"""

