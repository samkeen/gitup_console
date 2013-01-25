#!/usr/bin/env ruby
require 'yaml'
require 'set'

TOP_DIR = File.dirname(File.expand_path(File.dirname(__FILE__)))

puts TOP_DIR

settings = YAML::load File.open("#{TOP_DIR}/settings.yml")



# after scan, we need to know:
# - the set of known submodules
# - foreach sub, which repos contain it
def scan known_repos
  submodule_map = {}
  known_submodules = Set.new
  known_repos.each do |repo|
    repo['submodules'].each do |submodule|
      submodule_name =  File.basename submodule
      known_submodules.add submodule_name
      (submodule_map[submodule_name] ||= {})[repo['name']] = repo
    end
  end
  submodule_map
end

p scan settings['known_repos']