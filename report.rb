#!/usr/bin/env ruby

# This in the non-interactive, non-mutating version
# When run, it only reports the status of the repos with respect the
# the submodule

$LOAD_PATH.unshift( File.join( File.dirname(__FILE__), 'src' ) )

# Get the full path to this directory
THIS_DIR = File.expand_path(File.dirname(__FILE__))
# This with be a dir created and will house all the
# checked out code from git repositories.  No artifacts will be
# created outside of this directory
BUILD_DIR          = "#{THIS_DIR}/build/git_checkouts"
SRC_DIR            = "#{THIS_DIR}/src"
SETTINGS_FILE_PATH = "#{THIS_DIR}/settings.yml"

require 'colorize'
require 'yaml'
require 'updater'
require 'git_commander'
require 'command_line_args'
include CommandLineArgs

options = {
    :jenkins => {
        :found  => false,
        :value  => nil,
        :keyval => false
    },
    :verbose => {
        :found  => false,
        :value  => nil,
        :keyval => true
    }
}

args = CommandLineArgs::parse_cmd_line_args(__FILE__, options)

verbose = args[:verbose][:found]
ci_mode = args[:jenkins][:found]

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

settings['build_dir']     = BUILD_DIR
settings['templates_dir'] = "#{THIS_DIR}/src/templates"

git_commander = GitCommander.new(settings, Command.new(verbose), Stdout.new)
updater = Updater.new(Stdout.new, git_commander, settings, :verbose => verbose)

updater.report(ci_mode)