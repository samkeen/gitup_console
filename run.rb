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


settings = nil
if File.file? SETTINGS_FILE_PATH
  settings = YAML::load File.open(SETTINGS_FILE_PATH)
else
  puts "No settings file found at: #{SETTINGS_FILE_PATH}".colorize :red
  exit 1
end

settings['build_dir'] = BUILD_DIR

updater = Updater.new(Stdout.new, settings, :verbose => verbose)

puts updater.get_menu

updater.record_menu_input()

if updater.has_repos_to_clone?
    updater.process_repos
else
    puts 'No valid repo indexes found, nothing to process'.colorize :yellow
end