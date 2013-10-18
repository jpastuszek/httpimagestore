Feature: Request matching
	Incoming requests needs to be matched in flexible way and appropriate data needs to be available in form of variables used to parametrize processing.

	Background:
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		get "handler1" {
			output_text "path: #{path}"
		}
		"""
