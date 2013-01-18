# General Utility module for this App's Rake file
require 'open3'
class Command
  # this works, though it does not 'stream' stdout.  Instead gathers it all in buffer
  # then pukes it all out at once (causing long pauses during a build run with no output)
  #
  # @TODO Make this stream standard out.
  #
  # @param [String] command The bash command to run
  # @param [Hash] options
  # @return [String] STDOUT (also puts STDOUT)
  def run_command(command, options = {})
    options[:fail_on_error] ||= false
    options[:quiet]         ||= false
    begin
      puts "#{Dir.pwd}> #{command}"
      stdout_str, stderr_str, status = Open3.capture3(command)
      if status.exitstatus == 0 and ! stderr_str.empty?
        puts stderr_str
      end
      if status.exitstatus > 0 and ! stderr_str.empty?
        raise stderr_str
      end
      if status.exitstatus > 0 and options[:fail_on_error]
        raise "received exit code: #{status.exitstatus}"
      end
    rescue Exception => e
      puts stdout_str
      puts "Exiting... error message: #{e.message}"
      exit 1
    end
    puts stdout_str unless options[:quiet]
    stdout_str
  end
end