Feature: Original image and it's thumnails generation and storing on S2
	In order to store original image and it's thumbnails in configured S3 buckte
	A user must PUT image data to URI representing it's pathi with bucket
	The respons will be paths to files storred in S3

	Scenario: Putting thumbnails and original to S3 bucket
		Given test.jpg file content as request body
		When I do PUT request /thumbnail/small,tiny/test/image/test.jpg
		Then I will get the following response body
		"""
		http://rhthumbnails.s3.amazonaws.com/test/image/4006450256177f4a/test.jpg
		http://rhthumbnails.s3.amazonaws.com/test/image/4006450256177f4a/test-small.jpg
		http://rhthumbnails.s3.amazonaws.com/test/image/4006450256177f4a/test-tiny.jpg
		"""
