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

Given /httpimagestore log is empty/ do
		(support_dir + 'server.log').truncate(0)
end

Given /httpthumbnailer log is empty/ do
		(support_dir + 'thumbniler.log').truncate(0)
end

Given /(.*) file content as request body/ do |file|
	@request_body = File.open(support_dir + file){|f| f.read }
end

Given /(.*) S3 bucket with key (.*) and secret (.*)/ do |bucket, key_id, key_secret|
		@bucket = S3::Service.new(:access_key_id => key_id, :secret_access_key => key_secret).buckets.find(bucket)
end

Given /there is no (.*) file in S3 bucket/ do |path|
	@bucket.objects.find(path).destroy rescue S3::Error::NoSuchKey
end

Given /(.*) header set to (.*)/ do |header, value|
	@request_headers ||= {}
	@request_headers[header] = value
end

When /I do (.*) request (.*)/ do |method, uri|
	@response = HTTPClient.new.request(method, uri, nil, @request_body, (@request_headers or {}))
end

Then /response status will be (.*)/ do |status|
	@response.status.should == status.to_i
end

Then /response content type will be (.*)/ do |content_type|
	@response.header['Content-Type'].first.should == content_type
end

Then /response body will be CRLF ended lines like/ do |body|	
	@response.body.should match(body)
	@response.body.each do |line|
		line[-2,2].should == "\r\n"
	end
end

Then /response body will be CRLF ended lines$/ do |body|	
	@response.body.should == body.gsub("\n", "\r\n") + "\r\n"
end

Then /(http.*) content type will be (.*)/ do |url, content_type|
	get_headers(url)['Content-Type'].should == content_type
end

Then /(.*) will contain (.*) image of size (.*)x(.*)/ do |url, format, width, height|
	data = get(url)
	
	@image.destroy! if @image
	@image = Magick::Image.from_blob(data).first

	@image.format.should == format
	@image.columns.should == width.to_i
	@image.rows.should == height.to_i
end

Then /S3 bucket will not contain (.*)/ do |path|
	begin
		@bucket.objects.find(path)
		true.should eq(false, "object #{path} found in bucket")
	rescue S3::Error::NoSuchKey
		true.should == true
	end
end

