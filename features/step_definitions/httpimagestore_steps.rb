Given /httpimagestore server is running at (.*) with the following configuration/ do |url, config|
	cfile = Tempfile.new('httpimagestore.conf')
	cfile.write(config)
	cfile.close

	begin
		start_server(
			"bundle exec #{script('httpimagestore')} #{cfile.path}",
			'/tmp/httpimagestore.pid',
			support_dir + 'server.log',
			url
		)
	ensure
		cfile.unlink
	end
end

Given /httpthumbnailer server is running at (.*)/ do |url|
	start_server(
		"httpthumbnailer",
		'/tmp/httpthumbnailer.pid',
		support_dir + 'thumbniler.log',
		url
	)
end

Given /(.*) file content as request body/ do |file|
	@request_body = File.open(support_dir + file){|f| f.read }
end

When /I do (.*) request (.*)/ do |method, uri|
	@response = HTTPClient.new.request(method, uri, nil, @request_body)
end

Then /I will get matching response body/ do |body|	
	@response.body.should =~ Regexp.new(/^#{body}$/m)
end

Then /I will get the following response body/ do |body|	
	@response.body.should == body
end

