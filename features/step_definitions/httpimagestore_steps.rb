Given /httpimagestore server is running/ do
	start_server(
		"bundle exec #{script('httpimagestore')} #{support_dir + 'test.cfg'}",
		'/tmp/httpimagestore.pid',
		support_dir + 'server.log',
		'http://localhost:3000/'
	)
end

Given /httpthumbnailer server is running/ do
	start_server(
		"httpthumbnailer",
		'/tmp/httpthumbnailer.pid',
		support_dir + 'thumbniler.log',
		'http://localhost:3100/'
	)
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

