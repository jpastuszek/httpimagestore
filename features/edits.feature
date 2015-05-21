Feature: Applying multiple edits to thumbnails

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		post "edit_options" "&:edits?" "&:format?png" {
			thumbnail "input" "thumbnail" operation="fit" width=100 height=100 format="#{format}" edits="#{edits}"
			output_image "thumbnail"
		}
		"""

	@edits @options
	Scenario: Getting thumbnail with no edits
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/edit_options
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 71x100

	@edits @options
	Scenario: Getting thumbnail with one edit
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/edit_options?edits=rotate,90
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 100x71

	@edits @options
	Scenario: Getting thumbnail with multiple edits
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/edit_options?edits=rotate,90!rotate,30
		Then response status will be 200
		And response content type will be image/png
		Then response body will contain PNG image of size 100x91

	@edits @options
	Scenario: Getting thumbnail with multiple edits followed by some other param
		Given test.jpg file content as request body
		When I do POST request http://localhost:3000/edit_options?edits=rotate,90!rotate,30&format=jpg
		Then response status will be 200
		And response content type will be image/jpeg
		Then response body will contain JPEG image of size 100x91

