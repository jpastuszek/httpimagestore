Feature: Original image and it's thumnails generation and storing on S2
	In order to store original image and it's thumbnails in configured S3 buckte
	A user must PUT image data to URI representing it's pathi with bucket
	The respons will be paths to files storred in S3

	Background:
		Given httpimagestore log is empty
		Given httpimagestore server is running at http://localhost:3000/ with the following configuration
		"""
		s3_key 'AKIAJMUYVYOSACNXLPTQ', 'MAeGhvW+clN7kzK3NboASf3/kZ6a81PRtvwMZj4Y'
		s3_bucket 'issthumbtest'

		thumbnail_class 'small', 'crop', 128, 128
		thumbnail_class 'tiny', 'crop', 32, 32
		"""
		Given httpthumbnailer log is empty
		Given httpthumbnailer server is running at http://localhost:3100/

	Scenario: Putting thumbnails and original to S3 bucket
		Given test.jpg file content as request body
		When I do PUT request http://localhost:3000/thumbnail/small,tiny/test/image/test.jpg
		Then response status will be 200
		And response content type will be text/uri-list
		And response body will be CRLF endend lines
		"""
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny.jpg
		"""
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg will contain JPEG image of size 509x719
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg will contain JPEG image of size 128x128
		And http://issthumbtest.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny.jpg will contain JPEG image of size 32x32

