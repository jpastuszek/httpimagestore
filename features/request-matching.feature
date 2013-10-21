Feature: Request matching
	Incoming requests needs to be matched in flexible way and appropriate data needs to be available in form of variables used to parametrize processing.

	Background:
		Given httpthumbnailer server is running at http://localhost:3100/health_check
		Given httpimagestore server is running at http://localhost:3000/health_check with the following configuration
		"""
		# URI segment matchers
		get "string" {
			output_text "path: '#{path}'"
		}

		get "any" "default" ":test1" ":test2?foo" ":test3?bar" ":test4?baz" {
			output_text "test1: '#{test1}' test2: '#{test2}' test3: '#{test3}' test4: '#{test4}' path: '#{path}'"
		}
		get "any" ":test1" ":test2" {
			output_text "test1: '#{test1}' test2: '#{test2}' path: '#{path}'"
		}

		get "regexp1" ":test1/a.c/" ":test2/.*/" {
			output_text "test1: '#{test1}' test2: '#{test2}' path: '#{path}'"
		}
		get "regexp-404" ":test1/a.c.*/" ":test2/.*/" {
			output_text "test1: '#{test1}' test2: '#{test2}' path: '#{path}'"
		}

		# Query string matchers
		get "query" "key-value" "&hello=world" {
			output_text "query key-value matched path: '#{path}'"
		}

		get "query" "key" "default" "&:hello?abc" {
			output_text "key: '#{hello}' path: '#{path}'"
		}
		get "query" "key" "&:hello" {
			output_text "key: '#{hello}' path: '#{path}'"
		}
		"""

	@request-matching @string
	Scenario: Matching URI segment with strings
		When I do GET request http://localhost:3000/string/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		path: 'hello/world'
		"""

	@request-matching @capture-any
	Scenario: Capturing any URI segment
		When I do GET request http://localhost:3000/any/foo/bar/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		test1: 'foo' test2: 'bar' path: 'hello/world'
		"""

	@request-matching @capture-any-default
	Scenario: Capturing any URI segment with default value
		When I do GET request http://localhost:3000/any/default/foo/bar
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		test1: 'foo' test2: 'bar' test3: 'bar' test4: 'baz' path: ''
		"""

	@request-matching @capture-regexp
	Scenario: Capturing URI segment with regexp match
		When I do GET request http://localhost:3000/regexp1/abc/foobar/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		test1: 'abc' test2: 'foobar/hello/world' path: ''
		"""
		When I do GET request http://localhost:3000/regexp2/abc/foobar/hello/world
		Then response status will be 404

	@request-matching @query-key-value
	Scenario: Capturing URI by presence of given key-value query string pair
		When I do GET request http://localhost:3000/query/key-value/hello/world?hello=world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		query key-value matched path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key-value/hello/world?foo=bar&hello=world&bar=baz
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		query key-value matched path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key-value/hello/world
		Then response status will be 404
		When I do GET request http://localhost:3000/query/key-value/hello/world?hello=Xorld
		Then response status will be 404
		When I do GET request http://localhost:3000/query/key-value/hello/world?heXlo=world
		Then response status will be 404

	@request-matching @query-key
	Scenario: Capturing URI by query string key presence
		When I do GET request http://localhost:3000/query/key/hello/world?hello=world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'world' path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key/hello/world?foo=bar&hello=foobar&bar=baz
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'foobar' path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key/hello/world
		Then response status will be 404
		When I do GET request http://localhost:3000/query/key/hello/world?heXlo=world
		Then response status will be 404

	@request-matching @query-key-default
	Scenario: Capturing URI by query string key presence
		When I do GET request http://localhost:3000/query/key/default/hello/world?hello=world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'world' path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key/default/hello/world?foo=bar&hello=foobar&bar=baz
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'foobar' path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key/default/hello/world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'abc' path: 'hello/world'
		"""
		When I do GET request http://localhost:3000/query/key/default/hello/world?heXlo=world
		Then response status will be 200
		And response content type will be text/plain
		And response body will be CRLF ended lines
		"""
		key: 'abc' path: 'hello/world'
		"""

