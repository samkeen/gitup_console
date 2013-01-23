# General Utility module for this App's Rake file
require 'open3'
class Command

  # @param [Boolean] verbose_on
  def initialize(verbose_on=false)
    @verbose_on = verbose_on
  end
  # this works, though it does not 'stream' stdout.  Instead gathers it all in buffer
  # then pukes it all out at once (causing long pauses during a build run with no output)
  #
  # @TODO Make this stream standard out.
  #
  # @param [String] command The bash command to run
  # @param [Hash] options
  # @return [String] STDOUT
  def run_command(command, options = {})
    options[:fail_on_error] ||= false
    output = ''
    begin
      puts "#{Dir.pwd}> #{command}" if @verbose_on
      stdout_str, stderr_str, status = Open3.capture3(command)
      if status.exitstatus == 0 and ! stderr_str.empty?
        output << stderr_str
      end
      if status.exitstatus > 0 and ! stderr_str.empty?
        raise stderr_str
      end
      if status.exitstatus > 0 and options[:fail_on_error]
        raise "received exit code: #{status.exitstatus}"
      end
      output << stdout_str
    rescue Exception => e
      puts stdout_str
      puts "Exiting... error message: #{e.message}"
      exit 1
    end
    output
  end
end