Feature: Original image and it's thumnails generation and storing on S2
	In order to store original image and it's thumbnails in configured S3 buckte
	A user must PUT image data to URI representing it's pathi with bucket
	The respons will be paths to files storred in S3

	Scenario: Putting thumbnails and original to S3 bucket
		Given test.jpg file content as request body
		When I do PUT request /test/image/test.jpg
		Then I will get matching response body
		"""
		test/image/[^/]*/test.jpg
		test/image/[^/]*/test-small.jpg
		test/image/[^/]*/test-tiny.jpg
		"""
