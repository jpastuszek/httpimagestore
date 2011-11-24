require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'rspec/expectations'

require 'daemon'
require 'timeout'
require 'httpclient'
require "open3"
require "thread"
require 'tempfile'

def gem_dir
		Pathname.new(__FILE__).dirname + '..' + '..'
end

def features_dir
		gem_dir + 'features'
end

def support_dir
		features_dir + 'support'
end

def script(file)
		gem_dir + 'bin' + file
end

def get(url)
	HTTPClient.new.get_content(url)
end

def server_request(method, uri, query = nil, body = nil)
	HTTPClient.new.request(method, "http://localhost:3000#{uri}", query, body)
end

def start_server(cmd, pid_file, log_file, test_url)
	stop_server(pid_file)

	fork do
		Daemon.daemonize(pid_file, log_file)
		exec(cmd)
	end
	Process.wait

	ppid = Process.pid
	at_exit do
		stop_server(pid_file) if Process.pid == ppid
	end

	Timeout.timeout(10) do
		begin
			get test_url
		rescue Errno::ECONNREFUSED
			sleep 0.1
			retry
		end
	end
end

def stop_server(pid_file)
	pid_file = Pathname.new(pid_file)
	return unless pid_file.exist?

	pid = pid_file.read.strip.to_i

	Timeout.timeout(20) do
		begin
			loop do
				Process.kill("TERM", pid)
				sleep 0.1
			end
		rescue Errno::ESRCH
			pid_file.unlink
		end
	end
end

