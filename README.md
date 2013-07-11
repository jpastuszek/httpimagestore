# HTTP Image Store

HTTP API server for image thumbnailing and storage.
It is using [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) as image processing backend.

## Features

* fully configurable image processing and storage pipeline with custom API configuration capabilities
* thumbnailing of sourced or input image into one or more thumbnails
* sourcing and storage of images on file system
* sourcing and storage of images on [Amazon S3](http://aws.amazon.com/s3/)
* image output with Cache-Control header
* S3 public or private and http:// or https:// URL list output for stored images
* storage under custom paths including image hash, content determined extension or used URL path
* based on [Unicorn HTTP server](http://unicorn.bogomips.org) with UNIX socket communication support

## Installing

HTTP Image Store is released as gem and can be installed from [RubyGems](http://rubygems.org) with:

```bash
gem install httpimagestore
```

## Configuration

To start HTTP Image Store server you need to prepare API configuration first.
Configuration is written in [SDL](http://sdl4r.rubyforge.org) format.

Configuration is in general consists of:

* thumbnailer client configuration (optional)
* S3 client configuration (optional)
* storage paths configuration
* request handler (API) configuration
  * image sourcing operations
  * image storage operation
  * output operations

### Top level configuration elements

#### thumbnailer

Configures [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) client. It will be used to perform image processing operations.

Options:
* `url` - URL of [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) service

If omitted [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) service at located `http://localhost:3100` will be used.

Example:

```sdl
thumbnailer url="http://2.2.2.2:1000"
```

#### s3

Configures [Amazon S3](http://aws.amazon.com/s3/) client for S3 object storage and retrieval.

Options:

* `key` - API key to use
* `secret` - API secret for given key
* `ssl` - if `true` SSL protected connection will be used; storage URL will begin with `http://`; default: `true`

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false
```

#### path

This directive is used to define storage and retrieval paths that will be used when storing and sourcing file on file system or S3 service.
You can declare one path per statement or use `{}` brackets syntax to define more than one with single statement - they are semantically equal.

Arguments:

1. name - name of the path used later to reference it
2. pattern - path patter that can consists of characters and variables surrounded by `#{}`

Variables:

* `digest` - input image digest based on it's content only; this is first 16 hex characters from SHA2 digest; ex. `2cf24dba5fb0a30e`
* `path` - remaining (unmatched) request URL path
* `basename` - name of the file without it's extension determined from `path`
* `direname` - name of the directory determined form `path`
* `extension` - file extension determined from `path`
* `mimeextension` - image extension based on mime type; mime type will be updated based on information from **HTTP Thumbnailer** for input image and output thumbnails - content determined
* `imagename` - name of the image that is being stored or sourced
* URL matches - other variables can be matched from URL pattern, see API configuration

Example:

```sdl
path "uri"						"#{path}"
path "hash"						"#{digest}.#{extension}"

path {
	"hash-name"					"#{digest}/#{imagename}.#{extension}"
	"structured"				"#{dirname}/#{digest}/#{basename}.#{extension}"
	"structured-name"			"#{dirname}/#{digest}/#{basename}-#{imagename}.#{extension}"
}
```

#### API endpoint

This statement allows to configure single API endpoint and related operations that will be performed when matching request comes in to be handled.
Defined endpoints will be evaluated in order until one is matched.

Each endpoint can have one or more operation defined that will be performed on request matching that endpoint.

Statement should start with one of the following HTTP verbs in lowercase: `get`, `post`, `put`, `delete`, followed by list of URL section matchers:

* `string` - literal string will match that string in URL section
* `:symbol` - symbol beginning with `:` will match any URL section and will store matched string in variable named as symbol; this variable can then be used to build path, thumbnail parameters or any other places where variables are expanded
* `:symbol?` - symbol beginning with `:`  and followed with `?` will be optionally matched; request URL may not contain this section to be matched for this endpoint to be evaluated
* `:symbol/regexp/` - in this format symbol will be matched only if `/` surrounded [regular expression](http://rubular.com) matches the URL section

Example:

```sdl
get "thumbnail" "v1" ":path" ":operation" ":width" ":height" ":options?" {
}

put "thumbnail" "v1" ":thumbnail_class/small|large/" {
}

post {
}
```

### API endpoint image sourcing operations

Sourcing will load images into memory for further processing.
Each image is stored under predefined or user defined name.

If endpoint HTTP verb is `post` or `put` then image data will be sourced from request body. It can be referenced using `input` name.

#### source_file

With this statements image can be sourced from file system.

Arguments:

1. image name - name under which the sourced image can be referenced

Options:

* `root` - file system path under which the images are looked up
* `path` - name of predefined path that will be used to locate the image file

Example:

```sdl
path "myimage"	"myimage.jpg"

get "small" {
	source_file "original" root="/srv/images" path="myimage"
}
```

Requesting `/small` URI will result with file `/srv/images/myimage.jpg` loaded into memory under `original` name.

#### source_s3

This statement can be used to load images from S3 bucket.
To use this bucket global `s3` statement needs to be used in top level to configure S3 client.

Arguments:

1. image name - name under which the sourced image can be referenced

Options:

* `bucket` - name of bucket to source image from
* `path` - name of predefined path that will be used to generate key to object to source

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false
path "myimage"	"myimage.jpg"

get "small" {
	source_s3 "original" bucket="mybucket" path="myimage"
}
```

Requesting `/small` URI will result with image fetched from S3 bucket `mybucket` and key `myimage.jpg` and named `original`.

#### thumbnail

This source will provide new images based on already sourced images by processing them with [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) backend.
This statement can be used to do single thumbnail operation or use multipart output API of the [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) when multiple operation are defined.
For more informations of meaning of options see [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) documentation.

Arguments:

1. source image name - thumbnailer input image of which thumbnail will be generated
2. thumbnail name - name under which the thumbnail image can be referenced

Options:

* `operation` - backend supported thumbnailin operation like `pad`, `fit`, `limit`, `crop`
* `width` - requested thumbnail width in pixels
* `height` - requested thumbnail height in pixels
* `format` - format in which the resulting image will be stored; all backend supported formats can be specified like `jpeg` or `png`; default: `jpeg`
* `options` - list of options in format `key:value[,key:value]*` to be passed to thumbnailer; this can be a list of any backend supported options like `background-color` or `quality`
* backend supported options - options can also be defined as statement options

Note that you can use `#{variable}` expansion within all of this options.

Example:

```sdl
put ":operation" ":width" ":height" ":options" {
	thumbnail "input" {
		"original" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"
		"small"		operation="crop"	width=128	height=128	format="jpeg"
		"padded"	operation="pad"		width=128	height=128	format="png"	background-color="gray"
	}
}
```

Putting image under `/pad/128/256/backgroud-color=green` URI will result with three thumbnails generated with single [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) request from `input` image into `original`, `small` and `padded` references.
`original` image will have width of 128 pixels and height of 256 pixels; the image will be centered and padded with color green background to match this dimensions; it will be a JPEG image, saved with compression quality of 84.

You can also use shorter form that will perform only one thumbnailing operation per statement using [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer)'s single thumbnail API:

```sdl
put ":operation" ":width" ":height" ":options" {
	thumbnail "input" "original" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"
}
```

### API endpoint storage operations

This statements are executed after all source statements are finished.
They allow storing of any sourced images by specifying their references.

#### store_file

This statement can store image in file system.

Arguments:

1. image name - image to be stored

Options:

* `root` - file system path under which the images are stored
* `path` - name of predefined path that will be used to store the image file under; relative to `root`

Example:

```sdl
path "imagename"	"#{name}"
path "hash"			"#{digest}"

put "store" ":name" {
	store_file "input" root="/srv/images" path="imagename"
	store_file "input" root="/srv/images" path="hash"
}
```

Putting image data to `/store/hello.jpg` will store two copies of the image: one under `/srv/images/hello.jpg` and second under its digest like `/srv/images/2cf24dba5fb0a30e`.

#### store_s3

S3 bucket can also be used for image storage.
To use this bucket top level `s3` statement needs to be used to configure S3 client.

Arguments:

1. image name - image to be stored

Options:

* `bucket` - name of bucket to store image in
* `path` - name of predefined path that will be used to generate key to store object under
* `public` - if set to `true` the image will be readable by everybody; this affects fromat of output URL; default: `false`

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "imagename"	"#{name}"
path "hash"			"#{digest}"

put ":name" {
	store_s3 "input" bucket="mybucket" path="imagename"
	store_s3 "input" bucket="mybucket" path="hash"
}
```

Putting image data to `/store/hello.jpg` will store two copies of the image under `mybucket`: one under key `hello.jpg` and second under its digest like `2cf24dba5fb0a30e`.

### API endpoint output operations

When all images are stored output statements are processed.
They are responsible with generating HTTP response for the API endpoint.
If not output statement is specified the server will respond with `200 OK` and `OK` in response body.

#### output_image

This statement will produce `200 OK` response containing referenced image data.

It will set `Content-Type` header to mime-type of the image that was determined by [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) based on image data if image was used as input in thumbnailing or it is resulting thumbnail. If the mime-type is unknown `application/octet-stream` will be used.

Arguments:

1. image name - image to be sent in response body

Options:

* `cache-control` - value of response `Cache-Control` header can be specified with this option

Example:

```sdl
put "test" {
	output_image "input" cache-control="public, max-age=999, s-maxage=666"
}
```

The output will contain the posted image with `Content-Type` header set to `application/octet-stream` and `Cache-Control` to `public, max-age=999, s-maxage=666`.

#### output_store_path

This statement will output actual storage path on the file system (without root) or S3 bucket stored image.

The `Content-Type` of response will be `text/plain`.
You can specify multiple image names to output multiple paths of referenced images, each ended with `\r\n`.

Arguments:

1. image names - names of images to output storage path for in order

Example:

```sdl
path "out"	"test.out"

put "single" {
	store_file "input" root="/srv/images" path="out"

	output_store_path "input"
}
```

Putting image data to `/single` URI will result with image data stored under `/srv/images/test.out`. The response body will consist of `\r\n` ended line containing `test.out`.

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path {
	"in"	"test.in"
	"out"	"test.out"
	"out2"	"test.out2"
}

put "multi" {
	source_file "original" root="/srv/images" path="in"

	store_file "input" root="/srv/images" path="out"
	store_file "original" root="/srv/images" path="out2"

	output_store_path {
		"input"
		"original"
	}
}
```

Putting image data to `/multi` URI will result with image `original` sourced from `/srv/images/test.in` and stored under `/srv/images/out2`. The input data will also be stored under `/srv/images/test.out`. The response body will contain `\r\n` ended lines: `test.out` and `test.out2`.

#### output_store_url

This is similar statement to `output_store_file` but it will output `file://` URL for file stored images and valid S3 access URL for S3 stored images.

For S3 stored image if `ssl` is set to `true` on the S3 client statement (`s3 ssl="true"`) the URL will start with `https://`. If `public` is set to `true` when storing image in S3 (`store_s3 public="true"`) then the URL will not contain query string options, otherwise authentication tokens and expiration token (set to expire in 20 years) will be include in the query string.

The `Content-Type` header of this response is `text/uri-list`.
Each output URL is `\r\n` ended.

Arguments:

1. image names - names of images 

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "hash"			"#{digest}.#{mimeextension}"
path "hash-name"	"#{digest}/#{imagename}.#{mimeextension}"

put "thumbnail" {
	thumbnail "input" {
		"small"		operation="crop"	width=128	height=128	format="jpeg"
		"tiny_png"	operation="crop"	width=32	height=32	format="png"
	}

	store_s3 "input"	bucket="mybucket"		path="hash"		 public=true
	store_s3 "small"	bucket="mybucket"		path="hash-name" public=true
	store_s3 "tiny_png"	bucket="mybucket"		path="hash-name" public=true

	output_store_url {
		"input"
		"small"
		"tiny_png"
	}
}
```

Putting image data will result in storage of that image and two thumbnails generated from it. The output will contain `\r\n` ended lines like:

```
http://mybucket.s3.amazonaws.com/4006450256177f4a.jpg
http://mybucket.s3.amazonaws.com/4006450256177f4a/small.jpg
http://mybucket.s3.amazonaws.com/4006450256177f4a/tiny_png.png
```

#### output_source_file and output_source_url

This statements are similar to their storage variants but will output path and URL of the source locations.

### API endpoint meta options

Additional meta options can be used with selected statements.

#### if-image-name-on

It can be used with all source, storage and file/url output statements.
The argument will expand `#{variable}`.

If specified on or withing given statement it will cause that statement or it's part to be ineffective unless the image name used within the statement is on the list of image names specified as value of the option.
The list is in format `image name[,image name]*`.

This option is useful when building API that works on predefined set of image operations and allows to select witch set of operations to perform with list included in the URL.

### Complete example

This complete API configuration presents API compatible with previous version of httpimagestore (v0.5.0) and thumbnail on demand API.

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

# Compatibility API
path "compat-hash"				"#{digest}.#{mimeextension}"
path "compat-hash-name"			"#{digest}/#{imagename}.#{mimeextension}"
path "compat-structured"		"#{dirname}/#{digest}/#{basename}.#{mimeextension}"
path "compat-structured-name"	"#{dirname}/#{digest}/#{basename}-#{imagename}.#{mimeextension}"

put "thumbnail" ":name_list" ":path/.+/" {
	thumbnail "input" {
		# Make limited source image for migration to on demand API
		"migration"			operation="limit"	width=2160	height=2160	format="jpeg" quality=95

		# Backend classes
		"original"			operation="crop"		width="input"	height="input"	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
		"search"			operation="pad"		width=162	height=162	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
		"brochure"			operation="pad"		width=264	height=264	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
	}

	# Store migartion source image into on demand API bucket
	store_s3 "migration"		bucket="mybucket_v1"		path="hash"

	# Save input image for future reprocessing
	store_s3 "input"			bucket="mybucket"	path="compat-structured"	public=true

	# Backend classes
	store_s3 "original"			bucket="mybucket"	path="compat-structured-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"
	store_s3 "search"			bucket="mybucket"	path="compat-structured-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"
	store_s3 "brochure"			bucket="mybucket"	path="compat-structured-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"

	output_store_url {
		"input"
		"original"			if-image-name-on="#{name_list}"
		"search"			if-image-name-on="#{name_list}"
		"brochure"			if-image-name-on="#{name_list}"
	}
}

put "thumbnail" ":name_list" {
	thumbnail "input" {
		# Make limited source image for migration to on demand API
		"migration"			operation="limit"	width=2160	height=2160	format="jpeg" quality=95

		# Backend classes
		"original"			operation="crop"	width="input"	height="input"	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
		"search"			operation="pad"		width=162	height=162	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
		"brochure"			operation="pad"		width=264	height=264	format="jpeg" options="background-color:0xF0F0F0" if-image-name-on="#{name_list}"
	}

	# Store migartion source image into on demand API bucket
	store_s3 "migration"		bucket="mybucket_v1"		path="hash"

	# Save input image for future reprocessing
	store_s3 "input"			bucket="mybucket"	path="compat-hash"	public=true

	# Backend classe 
	store_s3 "original"			bucket="mybucket"	path="compat-hash-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"
	store_s3 "search"			bucket="mybucket"	path="compat-hash-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"
	store_s3 "brochure"			bucket="mybucket"	path="compat-hash-name"	public=true cache-control="public, max-age=31557600, s-maxage=0" if-image-name-on="#{name_list}"

	output_store_url {
		"input"
		"original"			if-image-name-on="#{name_list}"
		"search"			if-image-name-on="#{name_list}"
		"brochure"			if-image-name-on="#{name_list}"
	}
}

# Thumbnail on demand API 
path "hash"	"#{digest}.#{mimeextension}"
path "path"	"#{path}"

put "v1" "original" {
	thumbnail "input" "original" operation="limit" width=2160 height=2160 format="jpeg" quality=95

	store_s3 "original" bucket="mybucket_v1" path="hash"

	output_store_path "original"
}

get "v1" "thumbnail" ":path" ":operation" ":width" ":height" ":options?" {
	source_s3 "original" bucket="mybucket_v1" path="path"

	thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"

	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}
```

Compatibility API works by storing input image and selected (via URL) classes of thumbnalis generated during image upload. Once the image is uploaded thumbnails can be serverd directly from S3. There are two endpoints defined for that API to handle URLs that contain optional image storage name that results in usage of different storage key.

With thumbnail on demand API user uploads original image. It is converted to JPEG and if it is too large also scaled down. Than that processed version is stored in S3 under key composed from hash of input image data and final image extension. Client will receive storage key for further reference in the response body. To obtain thumbnail GET request with obtained key and thumbnail parameters encoded in the URL needs to be send to the sever. It will read parameters from the URL and source selected image from S3. That image is then thumbnailed in the backend and sent back to client with custom Cache-Control header.

Note that Compatibility API will also store "migarion" image in bucket used by on demand API. This allows for migration from that API to on demand API.

Compatibility API example:

```bash
# Uploading image and thumbnailing to 'original' and 'brochure' classes
$ curl -X PUT 10.1.1.24:3000/thumbnail/original,brochure -q --data-binary @Pictures/compute.jpg 
http://s3-eu-west-1.amazonaws.com/test.my.bucket/4006450256177f4a.jpg
http://s3-eu-west-1.amazonaws.com/test.my.bucket/4006450256177f4a/original.jpg
http://s3-eu-west-1.amazonaws.com/test.my.bucket/4006450256177f4a/brochure.jpg

# Obtaining 'brochure' class thumbnail
$ curl http://s3-eu-west-1.amazonaws.com/test.my.bucket/4006450256177f4a/brochure.jpg -v -s -o /tmp/test.jpg
* About to connect() to s3-eu-west-1.amazonaws.com port 80 (#0)
*   Trying 178.236.7.32... connected
> GET /test.my.bucket/4006450256177f4a/brochure.jpg HTTP/1.1
> User-Agent: curl/7.22.0 (x86_64-apple-darwin10.8.0) libcurl/7.22.0 OpenSSL/1.0.1c zlib/1.2.7 libidn/1.25
> Host: s3-eu-west-1.amazonaws.com
> Accept: */*
> 
< HTTP/1.1 200 OK
< x-amz-id-2: ZXJSWlUBthbIoUXztc9GkSu7mhpGK5HK+sVXWPdbCX9+a3nVkr4A6pclH1kdKjM9
< x-amz-request-id: 3DD4C96B6B55B4ED
< Date: Thu, 11 Jul 2013 11:33:31 GMT
< Cache-Control: public, max-age=31557600, s-maxage=0
< Last-Modified: Thu, 11 Jul 2013 11:31:36 GMT
< ETag: "cf060f47d557bcf9316554d34411dc51"
< Accept-Ranges: bytes
< Content-Type: image/jpeg
< Content-Length: 39458
< Server: AmazonS3
< 
{ [data not shown]
* Connection #0 to host s3-eu-west-1.amazonaws.com left intact
* Closing connection #0

$ identify /tmp/test.jpg
/tmp/test.jpg JPEG 264x264 264x264+0+0 8-bit sRGB 11.9KB 0.000u 0:00.009
```

On demand API example:

```bash
# Uploading image
$ curl -X PUT 10.1.1.24:3000/v1/original -q --data-binary @Pictures/compute.jpg 
4006450256177f4a.jpg

# Obtainig fit method 100x1000 thumbnail to /tmp/test.jpg
$ curl 10.1.1.24:3000/v1/thumbnail/4006450256177f4a.jpg/fit/100/1000 -v -s -o /tmp/test.jpg
* About to connect() to 10.1.1.24 port 3000 (#0)
*   Trying 10.1.1.24... connected
> GET /v1/thumbnail/4006450256177f4a.jpg/fit/100/1000 HTTP/1.1
> User-Agent: curl/7.22.0 (x86_64-apple-darwin10.8.0) libcurl/7.22.0 OpenSSL/1.0.1c zlib/1.2.7 libidn/1.25
> Host: 10.1.1.24:3000
> Accept: */*
> 
< HTTP/1.1 200 OK
< Server: nginx/1.2.9
< Date: Thu, 11 Jul 2013 11:26:15 GMT
< Content-Type: image/jpeg
< Content-Length: 4681
< Connection: keep-alive
< Status: 200 OK
< Cache-Control: public, max-age=31557600, s-maxage=0
< 
{ [data not shown]
* Connection #0 to host 10.1.1.24 left intact
* Closing connection #0

$ identify /tmp/test.jpeg
/tmp/test.jpeg JPEG 100x141 100x141+0+0 8-bit sRGB 4.68KB 0.000u 0:00.000
```

## Usage

To start this daemon you will need to prepar configuration as described about. Path to configuration file needs to be provided as last argument of `httpimagestore` daemon.

### Stand alone

In this mode `httpimagestore` daemon is listening on TCP port directly. This is the easiest way you can stert the daemon but it is not recommended for production use.
It is recommended to use [nginx](http://nginx.org) server in front of this daemon in porduction to buffer requests and responses.

To start this daemon in foreground for testing purposes with prepared `api.conf` configuration file use:

```bash
httpimagestore --verbose --foreground api.conf
```

Hitting Ctrl-C will ask the server to shutdown.

If you start it without `--foreground` switch the daemon will fork into background and write it's pid in `httpimagestore.pid` by default.

Note that in order to perform thumbnailing [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) needs to be running.

### Options

You can run `httpimagestore --help` to display all available switches, options and arguments.

Log file and pid file location can be controlled with `--log-file`, `--access-log-file` and `--pid-file` options.
To change number of worker processes use `--worker-processes`.
You can also change time out after witch worker process will be killed if it didn't provide response to request with `--worker-timeout`.
By default `httpimagestore` will not keep more than 128MiB of image data in memory - if this is exceeded it will send appropriate response code. The limit can be changed with `--limit-memory` option.

`--listener` can be used multiple times to define listening sockets; use `--listener /var/run/httpimagestore.sock` to listen on UNIX socket instead of TCP port **3000**.
`--user` switch can be used to force worker process to drop their privileges to specified user.

### Running with nginx

[nginx](http://nginx.org) if configured properly will buffer incoming requests before sending them to the backend and server response before sending them to client.
Since `httpimagestore` is based on [Unicorn HTTP server](http://unicorn.bogomips.org) that is based on single threaded HTTP request processing worker processes the number of processing threads is very limited. Slow clients could keep precious process busy for long time slowly sending request or reading response effectively rendering service unavailable.

Starting `httpimagestore` daemon with UNIX socket listener and `/etc/httpimagestore.conf` configuration file:

```bash
httpimagestore --pid-file /var/run/httpimagestore/pidfile --log-file /var/log/httpimagestore/httpimagestore.log --access-log-file /var/log/httpimagestore/httpimagestore_access.log --listener /var/run/httpimagestore.sock --user httpimagestore /etc/httpimagestore.conf
```

Starting `httpthumbnailer` daemon:

```bash
httpthumbnailer --pid-file /var/run/httpthumbnailer/pidfile --log-file /var/log/httpthumbnailer/httpthumbnailer.log --access-log-file /var/log/httpthumbnailer/httpthumbnailer_access.log --listener 127.0.0.1:3100 --user httpthumbnailer /etc/httpthumbnailer.conf
```

To start [nginx](http://nginx.org) we need to configure it to run as reverse HTTP proxy for our UNIX socket based `httpimagestore` backend.
Also we set it up so that it does request and response buffering.
Here is the example `/etc/nginx/nginx.conf` file:

```nginx
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log error;

pid        /var/run/nginx.pid;

events {
	worker_connections  1024;
}

http {
	include       /etc/nginx/mime.types;
	default_type  application/octet-stream;

	log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
			  '$status $body_bytes_sent "$http_referer" '
			  '"$http_user_agent" "$http_x_forwarded_for" $request_time';

	access_log  /var/log/nginx/access.log  main;

	sendfile        on;
	tcp_nopush		on;
	tcp_nodelay		off;

	keepalive_timeout		600s;
	client_header_timeout	10s;

	upstream httpimagestore {
		server unix:/var/run/httpimagestore.sock fail_timeout=0;
	}

	server {
		listen		*:3000;
		server_name	localhost;

		location / {
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header X-Forwarded-Proto $scheme;
			proxy_set_header Host $http_host;

			client_body_buffer_size		16m;
			client_max_body_size		128m;
			
			proxy_buffering				on;
			proxy_buffer_size			64k;
			proxy_buffers				256 64k;
			proxy_busy_buffers_size		256k;
			proxy_temp_file_write_size	128m;

			proxy_read_timeout			120s;
			proxy_connect_timeout		10s;

			proxy_pass http://httpimagestore;
		}
	}
}
```

Now it can be (re)started via usual init.d or systemd.

## Contributing to httpimagestore
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 Jakub Pastuszek. See LICENSE.txt for
further details.

