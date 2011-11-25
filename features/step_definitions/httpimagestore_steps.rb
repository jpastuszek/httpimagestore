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

Then /response status will be (.*)/ do |status|
	@response.status.should == status.to_i
end

Then /response content type will be (.*)/ do |content_type|
	@response.header['Content-Type'].first.should == 'text/plain'
end

Then /response body will be/ do |body|	
	@response.body.should == body
end

Then /(.*) will contain (.*) image of size (.*)/ do |url, image_type, image_size|
	data = get(url)
	Open3.popen3('identify -') do |stdin, stdout, stderr| 
		stdin.write data
		stdin.close
		path, type, size, *rest = *stdout.read.split(' ')
		type.should == image_type
		size.should == image_size
	end
end

