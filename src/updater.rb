require 'FileUtils'
require 'command'

class Updater

  # @param [Hash] settings
  # @param [Hash] options
  def initialize(settings, options = {})
    @settings        = settings
    @verbose_on      = options[:verbose]
    @requested_repos = []
    @repos_to_push   = []
    @commander       = Command.new
  end

  # @param [String] message
  def verbose(message)
    if @verbose_on
      puts message.colorize :cyan
    end
  end

  # @return [Boolean]
  def have_repos_to_clone?
    not @requested_repos.empty?
  end

  # @return [String]
  def get_menu
    menu_list = "  1) ALL\n"
    @settings['known_repos'].each_with_index do |repo, index|
      menu_list << "  #{index+2}) #{repo['name']}\n"
    end
    menu_list
  end

  def get_menu_input
    # get all the digits we see in the input
    # reduce each number by 2 to match the known_repo indexes
    user_inputs = gets.chomp.scan(/\d+/).uniq.map{ |digit| digit.to_i - 2 }
    highest_known_repo_index = @settings['known_repos'].count - 1
    user_inputs.each do |input|
      if input == -1
        @requested_repos = @settings['known_repos']
        puts 'You\'ve Selected ALL'.colorize(:yellow)
        @have_repos_to_clone=true
        break
      elsif input.between?(-1, highest_known_repo_index)
        @requested_repos << @settings['known_repos'][input]
        @have_repos_to_clone=true
      else
        puts "Unknown index: #{input+2}, ignoring it".colorize(:yellow)
      end
    end
    @requested_repos
  end

  # This is where all the heavy lifting happens
  def process_repos
    puts "Commit message: (used for the commit on each repo to describe the purpose of updating the '#{@settings['target_submodule_name']}' submodule)."
    commit_message = gets.chomp()
    # cleanup from the last build
    prep_build
    # get the current sha for the head of the target submodule branch
    verbose "First, I'll determine the sha for the HEAD of branch: '#{@settings['target_submodule_target_branch']}'  for the submodule to be updated."
    verbose 'With that known, I can determine if a given repo is "Up to Date" for that particular submodule.'
    clone_repo_to(@settings['target_submodule_name'], @settings['build_dir'])
    chdir_to_repo(@settings['target_submodule_name'])
    submodule_head_sha = checkout_branch(@settings['target_submodule_target_branch'])
    verbose("Determined [#{@settings['target_submodule_name']}]'s branch [#{@settings['target_submodule_target_branch']}]'s HEAD sha to be: #{submodule_head_sha}")

    verbose("\nNow starting the process of all the repos you've chosen to update\n")

    @requested_repos.each do |repo_to_clone|
      verbose("Processing repo: '#{repo_to_clone['name']}'")
      clone_repo_to(repo_to_clone['name'], @settings['build_dir'])
      chdir_to_repo(repo_to_clone['name'])
      checkout_branch(repo_to_clone['branch'])

      if submodule_up_to_date(repo_to_clone['submodule_dir'], submodule_head_sha)
        puts("The repo: #{repo_to_clone['name']} submodule {@settings['target_submodule_name']} is already up to date. Skipping".colorize(:yellow))
      else
        init_submodule(repo_to_clone['submodule_dir'])
        chdir_to_repo_submodule(repo_to_clone, @settings['target_submodule_name'])
        pull_branch_origin_latest(@settings['target_submodule_target_branch'])
        chdir_to_repo(repo_to_clone['name'])
        make_git_commit(commit_message, "#{repo_to_clone['submodule_dir']}/#{@settings['target_submodule_name']}")
        @repos_to_push << repo_to_clone
      end
    end
    if @repos_to_push.count > 0
      puts "#{@repos_to_push.count} have been updated and are ready to push.  Would you like me to do that?  [y/N]"
      user_input = gets.chomp.strip.upcase
      if user_input == 'Y'
        @repos_to_push.each do |repo|
          push_to_origin(repo['name'], repo['branch'])
        end
      end
    end
  end

  # Cleanup from previous runs of app.
  # Create any resources (dirs, etc) for the next build
  def prep_build
    verbose("Removing build dir at: #{@settings['build_dir']}")
    FileUtils.rm_rf(@settings['build_dir'])
    # create the build dir
    verbose("Creating build dir at: #{@settings['build_dir']}")
    FileUtils.mkdir(@settings['build_dir'])
  end

  # Clone the given git repo into the given target directory
  # @param [String] repo_name
  # @param [String] target_dir
  def clone_repo_to(repo_name, target_dir)
    clone_url         = "#{@settings['git_repo_base_clone_path']}/#{repo_name}.git"
    clone_target_path = "#{target_dir}/#{repo_name}"
    clone_cmd         = "git clone #{clone_url} #{clone_target_path}"
    verbose("Cloning Repo: '#{repo_name}' to: '#{clone_target_path}'")
    @commander.run_command(clone_cmd)
  end

  # Helper method to cd into the given (repo_name) repo dir.
  # @param [String] repo_name
  def chdir_to_repo(repo_name)
    repo_path = "#{@settings['build_dir']}/#{repo_name}"
    assert_path_exists(repo_path, "This is the expected path to the repo: #{repo_name}")
    verbose("Changing to dir: #{repo_path}")
    FileUtils.chdir(repo_path)
  end

  # Helper method to cd into the given repo's submodule dir.
  # @param [Array] repo_meta
  # @param [String] target_submodule
  def chdir_to_repo_submodule(repo_meta, target_submodule)
    repo_submodule_path = "#{@settings['build_dir']}/#{repo_meta['name']}/#{repo_meta['submodule_dir']}/#{target_submodule}"
    assert_path_exists(repo_submodule_path, "This is the expected path to the repo #{repo_meta['name']}'s' submodule: #{target_submodule}")
    verbose("Changing to dir: #{repo_submodule_path}")
    FileUtils.chdir(repo_submodule_path)
  end

  # Utility method to assert a filesystem path exists
  # @param [String] path
  # @param [String] additional_message
  def assert_path_exists(path, additional_message = '')
    if ! File.file? path and ! File.directory? path
      puts("path [#{path}] does not exist".colorize(:red))
      puts(additional_message.colorize(:red))
      exit 1
    end
  end

  # Checkout the given branch (branch_name) for the repo we are currently in
  # @param [String] branch_name
  # @return [String] checked out branch name
  def checkout_branch(branch_name)
    assert_known_branch(branch_name)
    current_branch_name = get_current_branch_name
    if branch_name == current_branch_name
      verbose("Already on branch '#{branch_name}', no need to checkout to that branch")
    else
      git_checkout_command = "git checkout #{branch_name}"
      verbose("Issuing command: #{git_checkout_command}")
      @commander.run_command(git_checkout_command)
    end
    @commander.run_command('git rev-parse HEAD').strip()
  end

  # @param [String] branch_name
  def assert_known_branch(branch_name)
    verbose "Asserting branch: '#{branch_name}' is a known branch for this repo"
    branch_list = get_branch_list()
    unless branch_list.include? branch_name
      puts("Branch #{branch_name} is an unknown branch.".colorize :yellow)
      puts("Known branches are: [#{branch_list.join(', ')}]".colorize :yellow)
      puts('Exiting...'.colorize(:red))
      exit 1
    end
  end

  # @return [Array]
  def get_branch_list
    branch_cmd_output = @commander.run_command('git branch')
    parts = branch_cmd_output.split(/\n/)
    # trim off whitespace and *'s
    parts.collect!{|x| x.tr(' *', '')}
  end

  # Get the name of the current git branch
  # @return [String]
  def get_current_branch_name
    branch_name_command = 'git rev-parse --abbrev-ref HEAD'
    verbose('Determining the current branch name')
    current_branch = @commander.run_command(branch_name_command).strip()
    verbose("Current branch name is: '#{current_branch}'")
    current_branch
  end

  # @param [String] submodule_relative_path
  # @param [String] submodule_target_sha
  # @return [Boolean]
  def submodule_up_to_date(submodule_relative_path, submodule_target_sha)
    git_submodule_status_command = "git submodule status #{submodule_relative_path}"
    sha_response = @commander.run_command(git_submodule_status_command)
    # parsing sha out of this type response -bd5fb0ce3d9646d9afd3cb4007b87d0cf1811a03 src/vendor/saccharin
    sha_response.match(/-([abcdef0-9]+) /)
    repos_submodule_sha = $1
    repos_submodule_sha == submodule_target_sha
  end

  # @param [String] submodule_path
  def init_submodule(submodule_path)
    assert_path_exists(submodule_path, 'This is the expected path to the Saccharin submodule')
    verbose("Initializing all submodules at path: '#{Dir.pwd}/#{submodule_path}'")
    @commander.run_command("git submodule update --init #{submodule_path}")
  end

  # Update current branch to the latest on origin
  # @param [String] branch_name
  # @return [String] STDOUT of the git pull command
  def pull_branch_origin_latest(branch_name)
    verbose "Update branch: '#{branch_name}' to the latest on origin "
    assert_known_branch(branch_name)
    @commander.run_command("git pull origin #{branch_name}")
  end

  # @param [String] commit_message
  # @return [String] The STDOUT of the git commit command
  # @param [String|Array] paths_to_add
  def make_git_commit(commit_message, paths_to_add)
    if paths_to_add.is_a? String
      paths_to_add = [paths_to_add]
    end
    paths_to_add.each do |path|
      @commander.run_command("git add #{path}")
    end
    commit_message.sub!('\'', '')
    @commander.run_command("git commit -m'#{commit_message}'")
  end

  # @param [String] repo_name
  # @param [String] branch_name
  def push_to_origin(repo_name, branch_name)
    repo_path = "#{@settings['build_dir']}/#{repo_name}"
    assert_path_exists repo_path, "Was cd'ing to the repo #{repo_name} in order to push it to origin but the dir was not there??"
    chdir_to_repo repo_name
    assert_known_branch branch_name
    verbose("Pushing repo [#{repo_name}]'s branch '#{branch_name}' to origin...")
    git_push_command = "git push origin #{branch_name}"
    puts "Would have run #{Dir.pwd}>#{git_push_command} here" #@commander.run_command(git_push_command)
  end

end