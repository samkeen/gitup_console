#!/usr/bin/env ruby

$LOAD_PATH.unshift( File.join( File.dirname(__FILE__), 'src' ) )

# Get the full path to this directory
THIS_DIR = File.expand_path(File.dirname(__FILE__))
# This with be a dir created and will house all the
# checked out code from git repositories.  No artifacts will be
# created outside of this directory
BUILD_DIR          = "#{ENV['HOME']}/.submodule_update"
SRC_DIR            = "#{THIS_DIR}/src"
SETTINGS_FILE_PATH = "#{THIS_DIR}/settings.yml"

require 'colorize'
require 'yaml'
require 'updater'

verbose = false
arg1 = ARGV[0]
ARGV.clear
case arg1
  when nil
    verbose = false
  when '-v', '--version'
    verbose = true
  else
    puts "Usage: #{__FILE__} [-v|--verbose]"
    exit 1
end

puts "\nThis script is implemented in a way to DO NO HARM. This is accomplished via: \n".colorize :green
puts "  * All local work with Repos is done in an isolated build directory [#{BUILD_DIR}]".colorize :green
puts "    None of your locally configured dev environments will be harmed".colorize :green
puts ""
puts "  * Multiple 'sanity check' confirmations occur during the process".colorize :green
puts "    If something doesn't look right for a repo, you can skip it and move to the next".colorize :green
puts ""
puts "  * This script will NEVER PUSH TO ORIGIN without your confirmation".colorize :green
puts ""
puts "  * Fully stateless. The build dir is removed and re-created for each run of the script\n".colorize :green

settings = nil
if File.file? SETTINGS_FILE_PATH
  settings = YAML::load File.open(SETTINGS_FILE_PATH)
else
  puts "No settings file found at: #{SETTINGS_FILE_PATH}".colorize :red
  exit 1
end

settings['build_dir'] = BUILD_DIR

updater = Updater.new(Stdout.new, settings, :verbose => verbose)

if ENV['REPORT']
  updater.report
else
  puts updater.get_menu

  updater.record_menu_input()

  if updater.has_repos_to_clone?
    updater.process_repos
  else
    puts 'No valid repo indexes found, nothing to process'.colorize :yellow
  end
end


