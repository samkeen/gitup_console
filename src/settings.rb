require 'yaml'
class Settings
  # parses and analyses the settings file.

  attr_reader :settings_file_path, :known_submodules, :submodule_map

  def initialize(settings_file_path)
    @settings_file_path = settings_file_path
    @known_submodules   = nil
    @submodule_map      = nil
  end

  # @return [Boolean]
  def good?
    if File.file? settings_file_path
      settings = YAML::load File.open(settings_file_path)
      raise "Was unable to parse file '#{settings_file_path}' as YAML" if settings.nil?
    else
      raise "No settings file found at: #{settings_file_path}"
    end
    @known_submodules, @submodule_map = scan(settings['known_repos'])
  end

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
    [known_submodules, submodule_map]
  end
end