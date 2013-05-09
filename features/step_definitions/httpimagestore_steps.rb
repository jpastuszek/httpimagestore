Given /httpimagestore argument (.*)/ do |arg|
	(@httpimagestore_args ||= []) << arg
end

Given /httpimagestore server is running at (.*) with the following configuration/ do |url, config|
	cfile = Tempfile.new('httpimagestore.conf')
	cfile.write(config)
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

Given /(.*) S3 bucket with key (.*) and secret (.*)/ do |bucket, key_id, key_secret|
	@bucket = RightAws::S3.new(key_id, key_secret, logger: Logger.new('/dev/null')).bucket(bucket)
end

Given /there is no (.*) file in S3 bucket/ do |path|
	@bucket.key(path).delete rescue S3::Error::NoSuchKey
end

Given /(.*) header set to (.*)/ do |header, value|
	@request_headers ||= {}
	@request_headers[header] = value
end

When /I do (.*) request (.*)/ do |method, uri|
	@response = HTTPClient.new.request(method, URI.encode(uri), nil, @request_body, (@request_headers or {}))
end

Then /response status will be (.*)/ do |status|
	@response.status.should == status.to_i
end

Then /response content type will be (.*)/ do |content_type|
	@response.header['Content-Type'].first.should == content_type
end

Then /response body will be CRLF ended lines like/ do |body|	
	@response.body.should match(body)
	@response.body.each_line do |line|
		line[-2,2].should == "\r\n"
	end
end

Then /response body will be CRLF ended lines$/ do |body|	
	@response.body.should == body.gsub("\n", "\r\n") + "\r\n"
end

Then /(http.*) content type will be (.*)/ do |url, content_type|
	get_headers(url)['Content-Type'].should == content_type
end

Then /(http.*) ([^ ]+) header will be (.*)/ do |url, header, value|
	get_headers(url)[header].should == value
end

Then /(http.*) ([^ ]+) header will not be set/ do |url, header|
	get_headers(url)[header].should be_nil
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
	@bucket.key(path).exists?.should_not be_true
end

