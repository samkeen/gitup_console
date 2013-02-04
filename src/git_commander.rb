class GitCommander
  # To change this template use File | Settings | File Templates.

  attr_reader :base_repo_path, :build_dir, :git_log_format, :git_log_num_lines, :commander, :stdout

  def initialize(settings, commander, stdout)
    @base_repo_path    = settings['git_repo_base_clone_path']
    @build_dir         = settings['build_dir']
    @git_log_format    = settings['git_log_format'] || '--pretty=format:"%h%x09%an%x09%ad%x09%s" --graph'
    @git_log_num_lines = settings['git_log_number_of_lines'] || 5
    @commander         = commander
    @stdout            = stdout
  end

  # @param [Integer] number_of_lines
  # @param [String] log_endpoints ex: 'HEAD..origin/master'
  def show_git_log(number_of_lines, log_endpoints=nil)
    num_lines_arg = number_of_lines.nil? ? '' : "-#{number_of_lines}"
    log_endpoints = log_endpoints.nil? ? '' : log_endpoints
    commander.run_command "git log #{git_log_format} #{num_lines_arg} #{log_endpoints}"
  end

  # Clone the given git repo into the given target directory
  # @param [String] repo_name
  # @param [String] target_dir
  def clone_repo_to(repo_name, target_dir)
    clone_url         = "#{base_repo_path}/#{repo_name}.git"
    clone_target_path = "#{target_dir}/#{repo_name}"
    clone_cmd         = "git clone #{clone_url} #{clone_target_path}"
    stdout.verbose("Cloning Repo: '#{repo_name}' to: '#{clone_target_path}'")
    stdout.verbose commander.run_command(clone_cmd)
  end

  # Checkout the given branch (branch_name) for the repo we are currently in
  # @param [String] branch_name
  # @return [String] checked out branch name
  def checkout_branch(branch_name)
    assert_known_branch(branch_name)
    current_branch_name = get_current_branch_name
    if branch_name == current_branch_name
      stdout.verbose("Already on branch '#{branch_name}', no need to checkout to that branch")
    else
      git_checkout_command = "git checkout #{branch_name}"
      stdout.verbose("Issuing command: #{git_checkout_command}")
      stdout.verbose commander.run_command(git_checkout_command)
    end
    sha_of_branch = commander.run_command('git rev-parse HEAD').strip()
    stdout.verbose sha_of_branch
    sha_of_branch
  end

  # @param [String] branch_name
  def assert_known_branch(branch_name)
    stdout.verbose "Asserting branch: '#{branch_name}' is a known branch for this repo"
    branch_list = get_branch_list()
    unless branch_list.include? branch_name
      stdout.out_warn "Branch #{branch_name} is an unknown branch."
      stdout.out_warn "Known branches are: [#{branch_list.join(', ')}]"
      stdout.out_error 'Exiting...'
      exit 1
    end
  end

  # @return [Array]
  def get_branch_list
    branch_cmd_output = commander.run_command('git branch')
    stdout.verbose branch_cmd_output
    parts = branch_cmd_output.split(/\n/)
    # trim off whitespace and *'s
    parts.collect!{|x| x.tr(' *', '')}
  end

  # Get the name of the current git branch
  # @return [String]
  def get_current_branch_name
    branch_name_command = 'git rev-parse --abbrev-ref HEAD'
    stdout.verbose('Determining the current branch name')
    current_branch = commander.run_command(branch_name_command).strip()
    stdout.verbose current_branch
    stdout.verbose("Current branch name is: '#{current_branch}'")
    current_branch
  end

  # @param [String] submodule_rel_path
  # @param [String] submodule_target_sha
  # @return [Boolean]
  def submodule_up_to_date(submodule_rel_path, submodule_target_sha)
    git_submodule_status_command = "git submodule status #{submodule_rel_path} #{submodule_rel_path}"
    sha_response = commander.run_command(git_submodule_status_command)
    stdout.verbose sha_response
    # parsing sha out of this type response " bd5fb0ce3d9646d9afd3cb4007b87d0cf1811a03 src/vendor/saccharin "
    sha_response[/\b[0-9a-f]{40}\b/] == submodule_target_sha
  end

  # @param [String] submodule_path
  def init_submodule(submodule_path)
    stdout.out_success("\nInitializing submodules at path: '#{Dir.pwd}/#{submodule_path}'")
    stdout.verbose commander.run_command("git submodule update --init #{submodule_path}")
  end

  # Update current branch to the latest on origin
  # @param [String] branch_name
  # @return [String] STDOUT of the git pull command
  def pull_branch_origin_latest(branch_name)
    stdout.verbose "Update branch: '#{branch_name}' to the latest on origin "
    assert_known_branch(branch_name)
    stdout.verbose commander.run_command("git pull origin #{branch_name}")
  end

  # @param [String] commit_message
  # @return [String] The STDOUT of the git commit command
  # @param [String|Array] paths_to_add
  def make_git_commit(commit_message, paths_to_add)
    if paths_to_add.is_a? String
      paths_to_add = [paths_to_add]
    end
    paths_to_add.each do |path|
      stdout.verbose commander.run_command("git add #{path}")
    end
    commit_message.sub!('\'', '')
    stdout.verbose commander.run_command("git commit -m'#{commit_message}'")
  end

  # @param [String] repo_name
  # @param [String] branch_name
  def push_to_origin(repo_name, branch_name)
    stdout.verbose("Pushing repo [#{repo_name}]'s branch '#{branch_name}' to origin...")
    git_push_command = "git push origin #{branch_name}"
    stdout.out commander.run_command(git_push_command)
  end
end