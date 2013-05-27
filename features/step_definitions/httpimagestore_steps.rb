Given /httpimagestore argument (.*)/ do |arg|
	(@httpimagestore_args ||= []) << arg
end

Given /httpimagestore server is running at (.*) with the following configuration/ do |url, config|
	cfile = Tempfile.new('httpimagestore.conf')
	cfile.write(config.replace_s3_variables)
	cfile.close

	begin
		log = support_dir + 'server.log'
		start_server(
			"bundle exec #{script('httpimagestore')} -f -d -l #{log} #{(@httpimagestore_args ||= []).join(' ')} #{cfile.path}",
			'/tmp/httpimagestore.pid',
			log,
			url
		)
	ensure
		cfile.unlink
	end
end

Given /httpthumbnailer server is running at (.*)/ do |url|
	log = support_dir + 'thumbniler.log'
	start_server(
		"httpthumbnailer -f -d -l #{log}",
		'/tmp/httpthumbnailer.pid',
		log,
		url
	)
end

Given /httpimagestore log is empty/ do
		log = support_dir + 'server.log'
		log.truncate(0) if log.exist?
end

Given /httpthumbnailer log is empty/ do
		log = support_dir + 'thumbniler.log'
		log.truncate(0) if log.exist?
end

Given /(.*) file content as request body/ do |file|
	@request_body = File.open(support_dir + file){|f| f.read }
end

Given /S3 settings in AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_S3_TEST_BUCKET environment variables/ do
	
	unless ENV['AWS_ACCESS_KEY_ID'] and ENV['AWS_SECRET_ACCESS_KEY'] and ENV['AWS_S3_TEST_BUCKET']
		fail "AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY or AWS_S3_TEST_BUCKET environment variables not set"
	end

	@bucket = AWS::S3.new(access_key_id: ENV['AWS_ACCESS_KEY_ID'], secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'], use_ssl: false).buckets[ENV['AWS_S3_TEST_BUCKET']]
end

Given /there is no (.*) file in S3 bucket/ do |path|
	@bucket.objects[path].delete # rescue S3::Error::NoSuchKey
end

Given /(.*) header set to (.*)/ do |header, value|
	@request_headers ||= {}
	@request_headers[header] = value
end

When /I do (.*) request (.*)/ do |method, uri|
	@response = HTTPClient.new.request(method, URI.encode(uri.replace_s3_variables), nil, @request_body, (@request_headers or {}))
end

Then /response status will be (.*)/ do |status|
	@response.status.should == status.to_i
end

Then /response content type will be (.*)/ do |content_type|
	@response.header['Content-Type'].first.should == content_type
end

Then /response body will be CRLF ended lines like/ do |body|	
	@response.body.should match(body.replace_s3_variables)
	@response.body.each_line do |line|
		line[-2,2].should == "\r\n"
	end
end

Then /response body will be CRLF ended lines$/ do |body|	
	@response.body.should == body.replace_s3_variables.gsub("\n", "\r\n") + "\r\n"
end

Then /(http.*) content type will be (.*)/ do |url, content_type|
	get_headers(url.replace_s3_variables)['Content-Type'].should == content_type
end

Then /(http.*) ([^ ]+) header will be (.*)/ do |url, header, value|
	get_headers(url.replace_s3_variables)[header].should == value
end

Then /(http.*) ([^ ]+) header will not be set/ do |url, header|
	get_headers(url.replace_s3_variables)[header].should be_nil
end

Then /(.*) will contain (.*) image of size (.*)x(.*)/ do |url, format, width, height|
	data = get(url.replace_s3_variables)
	
	@image.destroy! if @image
	@image = Magick::Image.from_blob(data).first

	@image.format.should == format
	@image.columns.should == width.to_i
	@image.rows.should == height.to_i
end

Then /S3 bucket will not contain (.*)/ do |path|
	@bucket.objects[path].exists?.should_not be_true
end

