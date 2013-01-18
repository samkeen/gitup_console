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

settings = nil
if File.file? SETTINGS_FILE_PATH
  settings = YAML::load File.open(SETTINGS_FILE_PATH)
else
  puts "No settings file found at: #{SETTINGS_FILE_PATH}".colorize :red
  exit 1
end

settings['build_dir'] = BUILD_DIR


updater = Updater.new(settings, :verbose => true)

puts updater.get_menu

input_repo_indexes = updater.get_menu_input()

puts input_repo_indexes.inspect

if updater.have_repos_to_clone?
    updater.process_repos
else
    puts 'No valid repo indexes found, nothing to process'.colorize :yellow
end

# grab the commandline arguments
#parser = argparse.ArgumentParser(description="This is a script that updates a git repo's submodule")
#parser.add_argument('-v', help='verbose output', action="store_true", dest='verbose', default=False)
#parser.add_argument('-p', help='prompt user to continue for all git interactions', action="store_true", dest='prompt_user', default=False)
#commandline_args = parser.parse_args()
#
#updater = Updater(settings, commandline_args)
#
#print updater.get_menu()
#
#input_repo_indexes = updater.get_menu_input()
#
#repos_to_clone = updater.get_repos_to_process(input_repo_indexes)
#
#if repos_to_clone:
#    updater.process_repos(repos_to_clone)
#else:
#    print Console.out("No valid repo indexes found, nothing to process", Console.WARN)