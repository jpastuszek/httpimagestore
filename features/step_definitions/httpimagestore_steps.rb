Before do
	server_start
	thumbnailer_start
	@request_body = nil
	@response = nil
	@response_multipart = nil
end

After do
	server_stop
	thumbnailer_stop
end

Given /(.*) file content as request body/ do |file|
	@request_body = File.open(support_dir + file){|f| f.read }
end

When /I do (.*) request (.*)/ do |method, uri|
	@response = server_request(method, uri, nil, @request_body)
end

Then /I will get matching response body/ do |body|	
	@response.body.should =~ Regexp.new(/^#{body}$/m)
end

Then /I will get the following response body/ do |body|	
	@response.body.should == body
end

