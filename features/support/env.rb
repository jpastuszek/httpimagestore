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
require 'RMagick'
require 'aws-sdk'
require 'httpimagestore/aws_sdk_regions_hack'
require 'digest'

class String
	def replace_s3_variables
		string = self.dup
		string.gsub!(/@AWS_ACCESS_KEY_ID@/, ENV['AWS_ACCESS_KEY_ID'])
		string.gsub!(/@AWS_SECRET_ACCESS_KEY@/, ENV['AWS_SECRET_ACCESS_KEY'])
		string.gsub!(/@AWS_S3_TEST_BUCKET@/, ENV['AWS_S3_TEST_BUCKET'])
		string
	end
end

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

def http_client
	client = HTTPClient.new
	#client.debug_dev = STDOUT
	client
end

def get(url)
	http_client.get_content(URI.encode(url))
end

def get_headers(url)
	http_client.get(URI.encode(url)).headers
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
		rescue Errno::ECONNREFUSED
			sleep 0.1
			retry
		end
	end
end

def stop_server(pid_file)
	pid_file = Pathname.new(pid_file)
	return unless pid_file.exist?

	#STDERR.puts http_client.get_content("http://localhost:3000/stats") if pid_file.to_s.include? 'httpimagestore'
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

