# HTTP Image Store

Configurable S3 or file system image storage and processing HTTP API server.
It is using [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) as image processing backend.

## Features

* fully configurable image processing and storage pipeline with custom API configuration capabilities
* thumbnailing and editing (rotate, crop, blur, etc.) of input or sourced image into one or more thumbnails
* sourcing and storage of images on file system
* sourcing and storage of images on [Amazon S3](http://aws.amazon.com/s3/)
* image output with Cache-Control header
* S3 public or private and http:// or https:// URL list output for stored images
* S3 read-through and write-through object cache
* storage under custom paths including image hash, content determined extension or used URI path
* data URI encoding of image body (for HTML inlining)
* HMAC based URI authentication
* based on [Unicorn HTTP server](http://unicorn.bogomips.org) with UNIX socket communication support

## Changelog

### 1.9.0
* added support for thumbnail edits
* `validate_uri_hmac` and `validate_header_hmac` support

### 1.8.0
* `output_store_url` support additional arguments: `scheme`, `port` and `host`
* `output_store_uri` support added
* fixed `output_store_url` URL formatting for `file_store`
* fixed parsing of POST body when query string matches are used
* decoding UTF-8 characters encoded with JavaScript encode() (%uXXXX) to support legacy/broken clients

### 1.7.0
* `output_data_uri_image` support
* `source_failover` support
* fixed possible data leak with nested template processing
* reporting `400 Bad Request` for non UTF-8 characters encoded in URLs
* syslog logging
* transaction ID tracking

### 1.6.0
* `output_store_path` and `output_store_url` `path` argument support
* encoding resulting file storage URL

### 1.5.0
* `output_ok` and `output_text` support
* named captures regexp matcher support
* better matcher debugging

### 1.4.0
* read-through and write-through S3 object cache support

### 1.3.0

* `identify` statement support (requires [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) v1.1.0 or higher)
* changed variable names: `imagename` to `image_name`, `mimeextension` to `image_mime_extension`, `digest` to `input_digest` (old names can still be used)
* added support for new variables: `uuid`, `input_sha256`, `image_digest`, `image_sha256`, `image_width`, `image_height`, `input_image_mime_extension`, `input_image_width`, `input_image_height`
* improved variable processing and logging

### 1.2.0

* matching for query string key and value
* getting query string key value into variable
* optional query string matchers with default value
* default values for optional segment matchers
* S3 storage prefix support

### 1.1.0

* passing thumbnailer options via query string parameters

## Installing

HTTP Image Store is released as gem and can be installed from [RubyGems](http://rubygems.org) with:

```bash
gem install httpimagestore
```

## Configuration

To start HTTP Image Store server you need to prepare API configuration first.
Configuration is written in [SDL](http://sdl4r.rubyforge.org) format.

Configuration consists of:

* thumbnailer client configuration (optional)
* S3 client configuration (optional)
* storage path definitions
* API endpoint definitions
  * request validation
  * image sourcing operations
  * image storage operations
  * output setup

### Top level configuration elements

#### thumbnailer

Configures [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) client. It will be used to perform image processing operations with `thumbnail` and `identify` statements.

Options:
* `url` - URL of [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) service; default: `http://localhost:3100`

Example:

```sdl
thumbnailer url="http://10.2.2.2:3100"
```

#### s3

Configures [Amazon S3](http://aws.amazon.com/s3/) client for S3 object storage and retrieval.

Options:

* `key` - API key to use
* `secret` - API secret for given key
* `ssl` - if `true` SSL protected connection will be used; source and storage URL will begin with `http://`; default: `true`

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false
```

#### path

This directive is used to define storage and retrieval paths that will be used when storing and sourcing file on file system or S3 service. They may also be used for generating output paths or URIs.
You can declare one path per statement or use `{}` brackets syntax to define more than one with single statement - they are semantically equal.

Arguments:

1. name - name of the path used later to reference it
2. pattern - path patter that can consists of characters and variables surrounded by `#{}`

Variables:

* `input_digest` - input image digest based on it's content only; this is first 16 hex characters from SHA256 digest; ex. `9f86d081884c7d65`
* `digest` - same as `input_digest`; deprecated, please use `input_digest` instead
* `input_sha256` - input image digest based on it's content only; this is whole hex encoded SHA256 digest; ex. `9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08`
* `input_image_mime_extension` - extension of input image determined from image mime type
* `input_image_width` - width in pixels of the input image
* `input_image_height` - height in pixels of the input image
* `image_digest` - digest of image being stored based on it's content only; this is first 16 hex characters from SHA256 digest; ex. `9f86d081884c7d65`
* `image_sha256` - digest of image being stored based on it's content only; this is whole hex encoded SHA256 digest; ex. `9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08`
* `image_name` - name of the image that is being stored or sourced
* `imagename` - same as `image_name`; deprecated, please use `image_name` instead
* `image_mime_extension` - extension of image being stored determined from image mime type
* `mimeextension` - same as `image_mime_extension`; deprecated, please use `image_mime_extension` instead
* `image_width` - width in pixels of the image that is being stored
* `image_height` - height in pixels of the image that is being stored
* `path` - remaining (unmatched) request URL path
* `basename` - name of the file without it's extension determined from `path`
* `direname` - name of the directory determined form `path`
* `extension` - file extension determined from `path`
* `uuid` - unique ID for request; ex. `1b68a767-8163-425a-a32c-db6ed7200343`
* URL matches and query string parameters - other variables can be matched from URL pattern and query string parameters - see API configuration

Notes:
* Input based variables can only be calculated for non GET requests where body is not empty.
* Image mime type, width and height will only be know if that image was sent to or received from [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) during thumbnailing or via `identify` statement.

Example:

```sdl
path "uri"						"#{path}"
path "hash"						"#{input_digest}.#{extension}"

path {
	"hash-name"					"#{input_digest}/#{image_name}.#{extension}"
	"structured"				"#{dirname}/#{input_digest}/#{basename}.#{extension}"
	"structured-name"			"#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{extension}"
}
```

#### HTTP API endpoint

This group of statements allows to configure single API endpoint.
Each endpoint can have one or more operation defined that will be performed on HTTP request matching that endpoint.

Endpoints will be evaluated in order of definition until one is matched or **404 Not Found** is returned.

Statement should start with one of the following HTTP verbs in lowercase: `get`, `post`, `put`, `delete`, followed by list of URI segment matchers:

* `<string>` - `<string>` literally match against URI segment in that position for the endpoint to be evaluated
* `:<symbol>` - match any URI segment in that position and store matched segment value in variable named `<symbol>`
* `:<symbol>?[defalut]` - optionally match URI segment in that position and store matched segment value in variable named `<symbol>`; request URI may not contain segment in that position (usually at the end of URI) to be matched for this endpoint to be evaluated; if `[default]` value is specified it will be used when no value was found in the URI, otherwise empty string will be used
* `:<symbol>/<regexp>/` - match remaining URI using `/` surrounded [regular expression](http://rubular.com) and store matched segments in variable named `<symbol>`
* `/<regexp>/` - match remaining URI using `/` surrounded [regular expression](http://rubular.com) and store zero or more named captures in variable named as corresponding capture name; e.g. `/(?<my_number>[0-9]+)/` - match a number and store it in `my_number` variable
* `&<key>=<value>` - match this endpoint when query string contains key `<key>` with value of `<value>` and store the `<value>` in variable named `<key>`
* `&:<key>` - match query string parameter of key `<key>` and store it's value in variable named `<key>`
* `&:<key>?[default]` - optionally match query string parameter of key `<key>`; when `[default]` is specified it will be used as variable value, otherwise empty string will be used

Note that any remaining unmatched URI part is stored in `path` variable.
Variable `query_string_options` is build from all query string parameters and can be used to specify options to [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer).

Note that variables can get overwritten in order of evaluation:
1. `path` variable value
2. all matched URI components and query string parameters in order of specification from left to right
3. `query_string_options` variable value

Note that URI components are URI decoded after they are matched.
Query string parameter values are URI decoded before they are matched.

Example:

```sdl
get "thumbnail" "v1" ":path" ":operation" ":width" ":height" ":options?" {
}

put "thumbnail" "v1" ":thumbnail_class/small|large/" {
}

post {
}
```

In this example first endpoint will be matched for **GET** request with URI like `/thumbnail/v1/abc.jpg/fit/100/100` or `/thumbnail/v1/abc.jpg/pad/100/100/background-color:green`.
Second endpoint will be matched only for **PUT** requests with URIs beginning with `/thumbnail/v1/small` and `/thumbnail/v1/large`.
Third endpoint will match any **POST** request.

### API endpoint validator operations

First any defined validators are executed against request to see if we should accept the request or reject it.

#### validate_uri_hmac

This statement sets up HMAC based URI authentication.
If HMAC provided with the request does not have the expected value the server will return **403 Forbidden** response.

Arguments:

1. query string key for HMAC value - query string parameter key that contains hex encoded HMAC value to be validated against

Options:

* `secret` - shared secret used to generate HMAC
* `digest` - digest used for HMAC; see OpenSSL digests for valid values; default: sha1 (for HMAC-SHA1 scheme)
* `exclude` - comma separated list of query string parameter keys that will be excluded form HMAC computation
* `remove` - comma separated list of query string parameter keys that will be removed from request for further processing

`exclude` is useful when your URI contains extra query string parameters not related to this API that would otherwise brake HMAC computation.
`remove` can be used to remove all extra (apart form the HMAC parameter itself) HMAC related query string parameters like date or nonce so they don't interact with further statements.
Adding additional `nonce` or `date` query string parameter can help with HMAC security by 'randomizing' it's value for same URIs - this won't play well with caching though.

Example:

```sdl
get "small" {
	validate_uri_hmac "hmac" secret="key"
}
```

In this example request URI `/small?hmac=a49182838f1b0b306614cea1d0fbcdab980717f7` will be valid.
The actual HMAC is computed from `/small` URI and secret `key` using HMAC-SHA1 scheme.
Note that `hmac` query string parameter will be removed from the request and won't be accessible by further statements.

#### validate_header_hmac

This statement is identical in function as `validate_uri_hmac` but takes value for URI from given request header instead.
This is useful when HTTP Image Store is behind proxy that rewrites URIs. This would normally brake HMAC computation but if it can store the original URI in a header this can be used instead for HMAC computation.

Arguments:

1. header name - name of request header that will contain original URI value that will be used for HMAC computation instead of the actual request URI
2. query string key for HMAC value - query string parameter key of the actual request URI that contains hex encoded HMAC value to be validated against

Options:

* `secret` - shared secret used to generate HMAC
* `digest` - digest used for HMAC; see OpenSSL digests for valid values; default: sha1 (for HMAC-SHA1 scheme)
* `exclude` - comma separated list of query string parameter keys that will be excluded form HMAC computation
* `remove` - comma separated list of query string parameter keys that will be removed from request for further processing

Example:

```sdl
get "small" {
	validate_header_hmac "X-ORIGINAL-URI" "hmac" secret="key"
}
```

In this example request URI `/my-rewritten-uri?hmac=a49182838f1b0b306614cea1d0fbcdab980717f7` will be valid if request comes with `X-ORIGINAL-URI` header of value `/small`.
Note that the actual request URI needs only to contain valid `hamc` query string parameter while the value of header needs only the URI necessary for validation - it is OK if it contains the `hmac` query string parameter since it will be removed before computation.
`remove` will operate on request as normal. `exclude` will operate on the value of the header for the computation to be valid.

## API endpoint image sourcing operations

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
* `prefix` - prefix object key with given prefix value; this does not affect format of output URL; prefix will not be included in source path output; default: empty
* `cache-root` - path to directory where S3 objects and meta-data will be cached when sourced from S3; read-through mode; if required information was found in cache object no S3 requests will be made; same directory can be used with different buckets since cache key consists of S3 bucket name and object key

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false
path "myimage"	"myimage.jpg"

get "small" {
	source_s3 "original" bucket="mybucket" path="myimage"
}
```

Requesting `/small` URI will result with image fetched from S3 bucket `mybucket` and key `myimage.jpg` and named `original`.


#### source_failover

This statement can be used to wrap around other sources.
HTTP Image Store will try wrapped sources one by one until one will succeed.
If all sources fail status code for error from the first source will be returned.

This source has no options.

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false
path "myimage"	"myimage.jpg"

get "small" {
	source_failover {
		source_s3 "original" bucket="mybucket" path="myimage"
		source_s3 "original" bucket="mybucket-backup" path="myimage"
	}
}
```

Requesting `/small` URI will result with image fetched from S3 bucket `mybucket`.
If `mybucket` does not contain key `myimage.jpg` than `mybucket-backup` will be tried.
If `mybucket-backup` does not contain the key than `404` status code will be returned.

### API endpoint processing operations

#### thumbnail

This source will provide new images based on already sourced images by processing them with [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) backend.
This statement can be used to do single thumbnail operation or use multipart output API of the [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) when multiple operation are defined.
For more informations of meaning of options see [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) documentation.

Arguments:

1. source image name - thumbnailer input image of which thumbnail will be generated
2. thumbnail name - name under which the thumbnail image can be referenced

Options:

* `operation` - backend supported thumbnailing operation like `pad`, `fit`, `limit`, `crop`
* `width` - requested thumbnail width in pixels
* `height` - requested thumbnail height in pixels
* `format` - format in which the resulting image will be encoded; all backend supported formats can be specified like `jpeg` or `png`; default: `jpeg`
* `options` - list of options in format `key:value[,key:value]*` to be passed to thumbnailer; this can be a list of any backend supported options like `background-color` or `quality`
* `edits` - list of edits in format supported by [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) (`[!<edit name>[,<edit arg>]*[,<edit option>:<edit option value>]*]*`)
* backend supported options - options can also be defined as statement options

Note that you can use `#{variable}` expansion within all of this options.

Example:

```sdl
put ":operation" ":width" ":height" ":options" {
	thumbnail "input" {
		"original"	operation="#{operation}" width="#{width}" height="#{height}" options="#{options}" quality=84 format="jpeg"
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

##### edit

`thumbnail` statement supports sub statement `edit` that will apply additional edits to the thumbnail image.
This edits are applied before `edits` option specified edits.

Arguments:

1. edit name - name of [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) supported edit
2. argument 1 - first argument
3. argument 2 - second argument
4. argument n - etc. depending on how many argument the edit needs

Options

* any options supported by named edit

Example:

```sdl
post "example" "&:rotate?0" "&:crop_x?0.0" "&:crop_y?0.0" "&:crop_w?1.0" "&:crop_h?1.0" "&:edits?" {
	thumbnail "input" "thumbnail" operation="pad" width=100 height=100 format="jpeg" edits="#{edits}" {
		edit "rotate" "#{rotate}"
		edit "crop" "#{crop_x}" "#{crop_y}" "#{crop_w}" "#{crop_h}"
	}
	output_image "thumbnail"
}
```

In this example each thumbnail will be first rotated by `rotate` query string parameter value and cropped by query string provided values `crop_x`, `crop_y`, `crop_w`, `crop_h`.
If query string parameter `edits` is provided it will be used to do additional edits after rotation and cropping is applied.

Example URI can look like this: `/example?rotate=90&crop_x=0.1&crop_y=0.1&crop_w=0.8&crop_h=0.8&edits=pixelate,0.2,0.1,0.6,0.6,size:0.03!rectangle,0.1,0.8,0.8,0.1,color:blue`.
Posted image will be rotated by 90 degree. Than the result will be cropped by 10% from each sied. Next middle region of the image will be pixelated and then blue rectangle will be drawn at the bottom of it. Finally thumbnail of dimensions 100 by 100 will be generated and provided as JPEG encoded image in response body.

#### identify

This statement allows for image mime type, width and height identification based on image content with use of [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer).
This is usefull when image is not taking part in thumbnailing process but variables that are based on meta data needs to be used for storage.

Example:

```sdl
path "size" "#{image_width}x#{image_height}.#{image_mime_extension}"

put "images" {
		identify "input"
		store_s3 "input" bucket="mybucket" path="size"
		output_store_path "input"
}
```

In this example input image is indentified by [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer). Received information is used to populate `image_width`, `image_height` and `image_mime_extension` variables used to generate S3 storage key.

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
path "imagename"	"#{image_name}"
path "hash"			"#{input_digest}"

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
* `prefix` - prefix storeage key with given prefix value; this does not affect fromat of output URL; prefix will not be included in storage path output; default: empty
* `cache-root` - path to directory where stored S3 objects and meta-data will be cached for future sourcing with `source_s3`; write-through mode; note that same directory needs to be configured with corresponding `source_s3` statement

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "imagename"	"#{image_name}"
path "hash"			"#{input_digest}"

put ":name" {
	store_s3 "input" bucket="mybucket" path="imagename"
	store_s3 "input" bucket="mybucket" path="hash"
}
```

Putting image data to `/store/hello.jpg` will store two copies of the image under `mybucket`: one under key `hello.jpg` and second under its digest like `2cf24dba5fb0a30e`.

### API endpoint output operations

After all images are stored the output statement is processed.
It is responsible for generating HTTP response for the API endpoint.
If no output statement is specified the server will respond with `200 OK` and `OK` in response body.

#### output_text

This statement will produce custom `text/plain` response.

Arguments:

1. text - text to be provided in response body; you can use `#{variable}` expansion

Options:

* `status` - numerical value for HTTP response status; default: 200
* `cache-control` - value for the `Cache-Control` response header

#### output_ok

This is the default output if none is specified.
It will always produce `200` status HTTP response with `OK` in it's body.

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

#### output_data_uri_image

This statement will produce `200 OK` response containing base64 encoded image data within data URI in format:

```
data:<image mime type>;base64,<base64 encoded image data>
```

No tailing new line/line feed is added to the output.

This may be used to include images directly in HTML pages or CSS.

The `Content-Type` of the response will be `text/uri-list`.
Image mime type will be provided within data URI and must be known before output is constructed or `500 Internal Server Error` will be served.

Arguments:

1. image name - image to be sent in response body

Options:

* `cache-control` - value of response `Cache-Control` header can be specified with this option

Example:

```sdl
put "test" {
	identify "input"
	output_data_uri_image "input" cache-control="public, max-age=31557600, s-maxage=0"
}
```

The output will contain base64 encoded posted image within data URI with `Content-Type` header set to `text/uri-list` and `Cache-Control` to `public, max-age=999, s-maxage=666`.

#### output_store_path

This statement will output actual storage path on the file system (without root) or S3 key under witch the image was stored.

The `Content-Type` of response will be `text/plain`.
You can specify multiple image names to output multiple paths of referenced images, each ended with `\r\n`.

Arguments:

1. image names - names of images to output storage path for in order

Options:

* `path` - name of predefined path that will be used to generate output path; `#{path}` variable and all derivative will be replaced with given image storage path; if not specified the actual storage path will be provided

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

This is similar statement to `output_store_file` but it will output `file:` URL for file stored images and valid S3 access URL for S3 stored images.

For S3 stored image if `ssl` is set to `true` on the S3 client statement (`s3 ssl="true"`) the URL will start with `https://`. If `public` is set to `true` when storing image in S3 (`store_s3 public="true"`) then the URL will not contain query string options, otherwise authentication tokens and expiration token (set to expire in 20 years) will be include in the query string.

The `Content-Type` header of this response is `text/uri-list`.
Each output URL is `\r\n` ended.

Arguments:

1. image names - names of images

Options:

* `scheme` - rewrite URL scheme with provided one; variables can be used; `#{path}` variable and all derivative will be replaced with given image storage path; `#{url}` variable will contain full original URL
* `host` - add/rewrite provided host to the URL; variables can be used; `#{path}` variable and all derivative will be replaced with given image storage path; `#{url}` variable will contain full original URL
* `port` - add provided port to the URL; variables can be used; `#{path}` variable and all derivative will be replaced with given image storage path; `#{url}` variable will contain full original URL
* `path` - name of predefined path that will be used to generate output URL path part; `#{path}` variable and all derivative will be replaced with given image storage path; if not specified the original URL will be provided; `#{url}` variable will contain full original URL

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "hash"			"#{input_digest}.#{image_mime_extension}"
path "hash-name"	"#{input_digest}/#{image_name}.#{image_mime_extension}"

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

#### output_store_uri

This is similar statement to `output_store_url` but it will output only path component of the URL for stored images.

The `Content-Type` header of this response is `text/uri-list`.
Each output URL is `\r\n` ended.

Arguments:

1. image names - names of images

Options:

* `path` - name of predefined path that will be used to generate output URL path part; `#{path}` variable and all derivative will be replaced with given image storage path; if not specified the original URL will be provided; `#{url}` variable will contain full original URL

Example:

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "hash"			"#{input_digest}.#{image_mime_extension}"
path "hash-name"	"#{input_digest}/#{image_name}.#{image_mime_extension}"

put "thumbnail" {
	thumbnail "input" {
		"small"		operation="crop"	width=128	height=128	format="jpeg"
		"tiny_png"	operation="crop"	width=32	height=32	format="png"
	}

	store_s3 "input"	bucket="mybucket"		path="hash"		 public=true
	store_s3 "small"	bucket="mybucket"		path="hash-name" public=true
	store_s3 "tiny_png"	bucket="mybucket"		path="hash-name" public=true

	output_store_uri {
		"input"
		"small"
		"tiny_png"
	}
}
```

Putting image data will result in storage of that image and two thumbnails generated from it. The output will contain `\r\n` ended lines like:

```
/4006450256177f4a.jpg
/4006450256177f4a/small.jpg
/4006450256177f4a/tiny_png.png
```

### API endpoint meta options

Additional meta options can be used with selected statements.

#### if-image-name-on

It can be used with all source, storage and file/url output statements.
The argument will expand `#{variable}`.

If specified on or withing given statement it will cause that statement or it's part to be ineffective unless the image name used within the statement is on the list of image names specified as value of the option.
The list is in format `image name[,image name]*`.

This option is useful when building API that works on predefined set of image operations and allows to select witch set of operations to perform with list included in the URL.

#### if-variable-matches

It can be used on most operation statements and sub statements (`edit`).

The argument can contain name of variable to or be in format `<name of variable>:<expected value>`.
In first from the statement will be executed if variable of given name exists and is non empty.
In second form the statement will be executed if variable value equals to expected value.

This option is useful for example to selectively execute statements based on query string parameters.

## Configuration examples

### Flexible API example

Features two storage approaches: with JPEG conversion and limiting in size - for user provided content - and storing literally.
POST requests will end up with server side generated storage key based on input data digest.
PUT requests can be used to store image under provided storage key.
Thumbnail GET API is similar to described in [Facebook APIs](https://developers.facebook.com/docs/reference/api/using-pictures/#sizes) for thumbnailing.
Stored object extension and content type is determined from image data.
S3 objects are cached on storage and on read if not cached already (read-through/write-through cache).

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

path "hash" "#{input_digest}.#{image_mime_extension}"
path "path" "#{path}"

## User uploaded content - always JPEG converted, not bigger than 2160x2160 and in hight quality compression
post "pictures" {
	thumbnail "input" "original" operation="limit" width=2160 height=2160 format="jpeg" quality=95
	store_s3 "original" bucket="mybucket" path="hash" cache-root="/var/cache/httpimagestore"
	output_store_path "original"
}

put "pictures" {
	thumbnail "input" "original" operation="limit" width=2160 height=2160 format="jpeg" quality=95
	store_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	output_store_path "original"
}

## Uploaded by admin for use on the website for example - store whatever was send
post "images" {
	identify "input"
	store_s3 "input" bucket="mybucket" path="hash" cache-root="/var/cache/httpimagestore"
	output_store_path "input"
}

put "images" {
	identify "input"
	store_s3 "input" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	output_store_path "input"
}

## Thumbailing - keep input format; default JPEG quality is 85
### Thumbnail specification from query string paramaters
get "pictures" "&:width" "&:height" "&:operation?crop" "&:background-color?white" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

get "pictures" "&:width" "&:height?1080" "&:operation?fit" "&:background-color?white" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

get "pictures" "&:height" "&:width?1080" "&:operation?fit" "&:background-color?white" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="background-color:#{background-color}"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

### Predefined thumbnailing specification
get "pictures" "&type=square" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="crop" width="50" height="50"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

get "pictures" "&type=small" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="fit" width="50" height="2000"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

get "pictures" "&type=normall" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="fit" width="100" height="2000"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

get "pictures" "&type=large" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	thumbnail "original" "thumbnail" operation="fit" width="200" height="2000"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}

## By default serve original image as is - JPEG for user content and what was send for admin uploaded images
get "pictures" {
	source_s3 "original" bucket="mybucket" path="path" cache-root="/var/cache/httpimagestore"
	output_image "original" cache-control="public, max-age=31557600, s-maxage=0"
}
```

For more information see [flexi feature test](https://github.com/jpastuszek/httpimagestore/blob/master/features/flexi.feature).

### Compatible and on demand API examples

This example can be used to create new API and migration between old and new approach.
It presents API compatible with previous version of httpimagestore (v0.5.0) and one possible thumbnail on demand approach API.

```sdl
s3 key="AIAITCKMELYWQZPJP7HQ" secret="V37lCu0F48Tv9s7QVqIT/sLf/wwqhNSB4B0Em7Ei" ssl=false

# Compatibility API
path "compat-hash"				"#{input_digest}.#{image_mime_extension}"
path "compat-hash-name"			"#{input_digest}/#{image_name}.#{image_mime_extension}"
path "compat-structured"		"#{dirname}/#{input_digest}/#{basename}.#{image_mime_extension}"
path "compat-structured-name"	"#{dirname}/#{input_digest}/#{basename}-#{image_name}.#{image_mime_extension}"

put "thumbnail" ":name_list" ":path/.+/" {
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
path "hash"	"#{input_digest}.#{image_mime_extension}"
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

get "v2" "thumbnail" ":operation" ":width" ":height" {
	source_s3 "original" bucket="mybucket_v1" path="path"
	thumbnail "original" "thumbnail" operation="#{operation}" width="#{width}" height="#{height}" options="#{query_string_options}" quality=84 format="png"
	output_image "thumbnail" cache-control="public, max-age=31557600, s-maxage=0"
}
```

Compatibility API works by storing input image and selected (via URI) classes of thumbnails generated during image upload. Once the image is uploaded thumbnails can be served directly from S3. There are two endpoints defined for that API to handle URIs that contain optional image storage name that results in usage of different storage key.

With thumbnail on demand API user uploads original image. It is converted to JPEG and if it is too large also scaled down. Than that processed version is stored in S3 under key composed from hash of input image data and final image extension. Client will receive storage key for further reference in the response body. To obtain thumbnail **GET** request with obtained key and thumbnail parameters encoded in the URI needs to be send to the sever. It will read parameters from the URI and source selected image from S3. That image is then thumbnailed in the backend and sent back to client with custom Cache-Control header.

Note that Compatibility API will also store "migration" image in bucket used by on demand API. This allows for migration from that API to on demand API.

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

# Getting fit operation 100x1000 thumbnail to /tmp/test.jpg
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

# Also form with query string passed options can be used to retrieve thumbnails
$ curl 10.1.1.24:3000/v2/thumbnail/pad/100/100/4006450256177f4a.jpg?background-color=green -v -s -o /tmp/test.jpg
* About to connect() to 10.1.1.24 port 3000 (#0)
*   Trying 10.1.1.24... connected
> GET /v2/thumbnail/pad/100/100/4006450256177f4a.jpg?background-color=green HTTP/1.1
> User-Agent: curl/7.22.0 (x86_64-apple-darwin10.8.0) libcurl/7.22.0 OpenSSL/1.0.1c zlib/1.2.7 libidn/1.25
> Host: 10.1.1.24:3000
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: nginx/1.2.9
< Date: Wed, 24 Jul 2013 11:38:39 GMT
< Content-Type: image/jpeg
< Content-Length: 3310
< Connection: keep-alive
< Status: 200 OK
< Cache-Control: public, max-age=31557600, s-maxage=0
<
{ [data not shown]
* Connection #0 to host 10.1.1.24 left intact
* Closing connection #0

$ identify /tmp/test.jpg
/tmp/test.jpg JPEG 100x100 100x100+0+0 8-bit sRGB 3.31KB 0.000u 0:00.000
```

## Usage

After installation of the gem the `httpimagestore` executable is installed in **PATH**.
This executable is used to start HTTP Image Service with given configuration file path as it's last argument.

### Stand alone

In this mode `httpimagestore` daemon is listening on TCP port directly. This is the easiest way you can start the daemon but it is not recommended for production use.
It is recommended to use [nginx](http://nginx.org) server in front of this daemon in production to buffer requests and responses.

To start this daemon in foreground for testing purposes with prepared `api.conf` configuration file use:

```bash
httpimagestore --verbose --foreground api.conf
```

Hitting Ctrl-C will ask the server to shutdown.

If you start it without `--foreground` switch the daemon will fork into background and write it's PID in `httpimagestore.pid` by default.

Note that in order to perform thumbnailing [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) needs to be running.

### Options

You can run `httpimagestore --help` to display all available switches, options and arguments.

PID file location can be controlled with `--pid-file` options.

To change number of worker processes use `--worker-processes`.
You can also change time after witch worker process will be killed if it didn't provide response to request with `--worker-timeout`.

By default `httpimagestore` will not keep more than 128MiB of image data in memory - if this is exceeded the daemon will abort processing and send response with 413 status. The limit can be changed with `--limit-memory` option.

`--listener` can be used multiple times to define listening sockets; use `--listener /var/run/httpimagestore.sock` to listen on UNIX socket instead of default TCP port **3000**.

If running as root you can use `--user` option to specify user with whose privileges the worker processes will be running.

### Logging

`httpimagestore` logs to `httpimagestore.log` file in current directory by default. You can change log file location with `--log-file` option and verbosity with `--verbose` or `--debug` switch.

Additionally `httpimagestore` will log requests in [common NCSA format](http://en.wikipedia.org/wiki/Common_Log_Format) to `httpimagestore_access.log` file. Use `--access-log-file` option to change location of access log.

Syslog logging can be enabled with `--syslog-facility` option followed by name of syslog facility to use. When enabled log files are not created and both application logs and access logs are sent to syslog.
Access logs will gain meta information that will include `"type":"http-access"` that can be used to filter access log entries out from application log entries.

With `--xid-header` option name of HTTP request header can be specified. Value of this header will be logged in meta information tag `xid` along side all request related log entries.
Named header will be passed down with requests to HTTP Thumbnailer for grater traceability.

Using `--perf-stats` switch will enable logging of performance statistics. This log entries will be logged with `"type":"perf-stats"`.

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
Also we set it up so that it does request and response buffering and on disk caching of GET requests.
You may want to disable caching if your GET URL resource is not immutable.
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

	# cache GET requests up to 256MiB in RAM and 130GiB on disk for up to 30 days of no access
	proxy_cache_path	/var/cache/nginx/httpimagestore levels=2:2 keys_zone=httpimagestore:256m max_size=130g inactive=30d;

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

			proxy_cache			httpimagestore;
			proxy_cache_key		"$request_uri";

			proxy_pass http://httpimagestore;
		}
	}
}
```

Now it can be (re)started via usual init.d or systemd.

## Status codes

HTTP Image Store will respond with different status codes on different situations.
If all goes well `200 OK` will be returned otherwise:

### 400

* bad thumbnail specification
* empty body when image data expected

### 403

* request not authentic

### 404

* no API endpoint found for given URL
* file not found
* S3 bucket key not found

### 413

* uploaded image is too big to fit in memory
* request body is too long
* too much image data is loaded in memory
* memory or pixel cache limit in the thumbnailer backend has been exhausted

### 415

* [HTTP Thumbnailer](https://github.com/jpastuszek/httpthumbnailer) backend cannot decode input image - see supported formats by the backend

### 500

* may be caused by configuration error
* unexpected error has occurred - see the log file

## Statistics API

HTTP Image Store comes with statistics API that shows various runtime collected statistics.
It is set up under `/stats` URI. You can also request single stat with `/stats/<stat name>` request.

Example:

```bash
$ curl 127.0.0.1:3000/stats
workers: 10
total_requests: 27032164
total_errors: 3785333
calling: 1
writing: 0
total_write_multipart: 0
total_write: 23246830
total_write_part: 0
total_write_error: 3785333
total_write_error_part: 0
total_thumbnail_requests: 16415809
total_thumbnail_requests_bytes: 1624475247201
total_thumbnail_thumbnails: 16414688
total_thumbnail_thumbnails_bytes: 61806698184
total_identify_requests: 9
total_identify_requests_bytes: 73948
total_file_store: 0
total_file_store_bytes: 0
total_file_source: 0
total_file_source_bytes: 0
total_s3_store: 115337
total_s3_store_bytes: 11420368878
total_s3_source: 17150098
total_s3_source_bytes: 1694190265856
total_s3_cache_hits: 17149566
total_s3_cache_misses: 1416670
total_s3_cache_errors: 0

$ curl 127.0.0.1:3000/stats/total_thumbnail_thumbnails
16414688
```

## Contributing to HTTP Image Store

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 - 2015 Jakub Pastuszek. See LICENSE.txt for further details.

