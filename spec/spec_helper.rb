$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'httpclient'
require 'daemon'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

def support_dir
	Pathname.new('spec/support')
end

def get(url)
	HTTPClient.new.get_content(url)
end

def status(url)
	HTTPClient.new.get(url).status
end

def headers(url)
	HTTPClient.new.get(url).headers
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

