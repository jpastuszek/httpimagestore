$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'faraday'
require 'daemon'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

end

def support_dir
	Pathname.new('spec/support')
end

def http_client
	@faraday ||= Faraday.new
end

def request(method, uri, body, headers)
	http_client.run_request(method.downcase.to_sym, uri.replace_s3_variables, body, headers || {})
end

def get(url)
	http_client.get(url).body
end

def status(url)
	http_client.get(url).status
end

def headers(url)
	http_client.get(url).headers
end

@@running_cmd = {}
def start_server(cmd, pid_file, log_file, test_url)
	if @@running_cmd[pid_file]
		return if @@running_cmd[pid_file] == cmd
		stop_server(pid_file)
	end

	fork do
		Daemon.daemonize(pid_file, log_file)
		log_file = Pathname.new(log_file)
		log_file.truncate(0) if log_file.exist?
		exec(cmd)
	end

	@@running_cmd[pid_file] = cmd

	ppid = Process.pid
	at_exit do
		stop_server(pid_file) if Process.pid == ppid
	end

	Timeout.timeout(10) do
		begin
			get test_url
		rescue Faraday::Error::ConnectionFailed
			sleep 0.1
			retry
		end
	end
end

def stop_server(pid_file)
	pid_file = Pathname.new(pid_file)
	return unless pid_file.exist?

	STDERR.puts http_client.get_content("http://localhost:3000/stats") if pid_file.to_s.include? 'httpimagestore'
	pid = pid_file.read.strip.to_i

	Timeout.timeout(20) do
		begin
			loop do
				Process.kill("TERM", pid)
				sleep 0.1
			end
		rescue Errno::ESRCH
			@@running_cmd.delete pid_file.to_s
			pid_file.unlink
		end
	end
end

class RequestStateBuilder
	def initialize
		@vals = {}
		@body = ''
		@matches = {}
		@path = ''
		@query_string = {}
		@request_uri = '/'
		@memory_limit = MemoryLimit.new
		@headers = {}

		yield self if block_given?
	end

	def body(body)
		@body = body
	end

	def matches(matches)
		@matches.merge! matches
	end

	def path(path)
		@path = path
	end

	def query_string(query_string)
		@query_string.merge! query_string
	end

	def request_uri(request_uri)
		@request_uri = request_uri
	end

	def memory_limit(memory_limit)
		@memory_limit = memory_limit
	end

	def headers(headers)
		@headers.merge! headers
	end

	def []=(key, val)
		@vals[key] = val
	end

	def get
		rs = Configuration::RequestState.new(@body, @matches, @path, @query_string, @request_uri, @memory_limit, @headers)
		@vals.each do |key, value|
			rs[key] = value
		end
		rs
	end
end

def request_state(&block)
	if block
		RequestStateBuilder.new(&block).get
	else
		RequestStateBuilder.new
	end
end

