require 'FileUtils'
require 'command'
require 'stdout'
require 'digest'
require 'mailer'

class Updater

  # @param [GitCommander] :git
  attr_reader :git, :settings, :repos_to_push, :stdout

  # @param [Stdout] stdout
  # @param [GitCommander] git_commander
  # @param [Hash] settings
  # @param [Hash] options
  def initialize(stdout, git_commander, settings, options = {})
    @git               = git_commander
    @settings          = settings
    @requested_repos   = []
    @repos_to_push     = []
    @repo_context      = ''
    @submodule_context = ''
    stdout.verbose_on  = options[:verbose]
    @stdout            = stdout
  end

  # @return [Boolean]
  def has_repos_to_clone?
    not @requested_repos.empty?
  end

  def report
    prep_build
    up_to_date_modules = {}
    need_to_update     = {}
    log_lines_lookup   = {}
    submodule_head_sha = determine_submodule_sha
    settings['known_repos'].each do |repo_to_clone|
      stdout.out_success("\nProcessing repo: '#{repo_to_clone['name']}'")
      git.clone_repo_to(repo_to_clone['name'], settings['build_dir'])
      chdir_to_repo(repo_to_clone['name'])
      submodule_path = "#{repo_to_clone['submodule_dir']}/#{settings['target_submodule_name']}"
      assert_path_exists(submodule_path, 'This is the expected path to the Saccharin submodule')
      git.init_submodule(submodule_path)
      git.checkout_branch(repo_to_clone['branch'])
      submodule_relative_path = "#{repo_to_clone['submodule_dir']}/#{settings['target_submodule_name']}"
      if git.submodule_up_to_date(submodule_relative_path, submodule_head_sha)
        up_to_date_modules[repo_to_clone['name']] = repo_to_clone
        stdout.out_warn "The repo: #{repo_to_clone['name']} submodule #{settings['target_submodule_name']} is already up to date. Skipping"
      else
        chdir_to_repo_submodule(repo_to_clone, settings['target_submodule_name'])
        log_lines = git.show_git_log(nil, "HEAD..origin/#{settings['target_submodule_target_branch']}").strip
        stdout.out log_lines
        repo_to_clone['log_lines'] = log_lines
        (log_lines_lookup[log_lines] || log_lines_lookup[log_lines]=[]) << repo_to_clone['name']
        need_to_update[repo_to_clone['name']] = repo_to_clone
        stdout.out_success "The repo: #{repo_to_clone['name']} submodule #{settings['target_submodule_name']} Needs updating"
      end
    end
    report = render_report(up_to_date_modules, need_to_update, log_lines_lookup)
    puts report
    if settings['report_email']
      puts "Mailing report to #{settings['report_email']}"
      mailer = Mailer.new
      mailer.send_email(settings['report_email'],
                        :from => 'ci@shopigniter.com', :from_alias => 'CI Server',
                        :subject => 'Submodule Report', :body => report)
    end
  end

  # @param [Hash] up_to_date_modules
  # @param [Hash] need_to_update
  # @param [Hash] log_lines_lookup
  def render_report(up_to_date_modules, need_to_update, log_lines_lookup)
    output = []
    output << "===== Up to Date Repos ======"
    if up_to_date_modules.empty?
      output << "Of the repos checked, NONE where up to date\n"
    else
      output << "These repos are up to date with respect to the [#{settings['target_submodule_name']}] submodule:"
      output << "   #{up_to_date_modules.keys.join(', ')}"
    end
    output << "\n===== Outdated Repos ======"
    if need_to_update.empty?
      output << "Of the repos checked, ALL where up to date"
    else
      output << "These repos need updating with respect to the [#{settings['target_submodule_name']}] submodule:\n"
      log_lines_lookup.each do |log_lines, repos|
        output << "These repos:"
        output << "    #{repos.join(', ')}"
        output << "all have this state to pull:"
        output << log_lines
      end
    end
    output = output.join("\n")
    puts output
    output
  end

  # @return [String]
  def get_menu
    menu_list = "  1) ALL (process all repos listed below)\n"
    settings['known_repos'].each_with_index do |repo, index|
      menu_list << "  #{index+2}) #{repo['name']} (Branch: '#{repo['branch']}')\n"
    end
    menu_list << ("\nEnter 1 for All, or a list of the Repos you want to process (ex: 2 4 5)".colorize :green)
    menu_list
  end

  def record_menu_input
    # get all the digits we see in the input
    # reduce each number by 2 to match the known_repo indexes
    user_inputs = gets.chomp.scan(/\d+/).uniq.map{ |digit| digit.to_i - 2 }
    highest_known_repo_index = settings['known_repos'].count - 1
    user_inputs.each do |input|
      if input == -1
        @requested_repos = settings['known_repos']
        stdout.out_success 'You\'ve Selected ALL'
        @have_repos_to_clone=true
        break
      elsif input.between?(-1, highest_known_repo_index)
        @requested_repos << settings['known_repos'][input]
        @have_repos_to_clone=true
      else
        stdout.out_warn "Unknown index: #{input+2}, ignoring it"
      end
    end
  end


  # Show user last (n) commits, so they can do a sanity check prior to pushing to origin
  # @param [String] repo_name
  # @param [String] branch_name
  def confirm_push(repo_name, branch_name)
    stdout.out_success("\nShowing last #{settings['git_log_number_of_lines']} lines of Repo '#{repo_name}', Branch '#{branch_name}' log\n")
    stdout.out git.show_git_log(settings['git_log_number_of_lines'])
    stdout.out_success("#{context_prompt} Confirm push of Repo '#{repo_name}', Branch '#{branch_name}' to Origin? [y/N]")
    gets.chomp.upcase == 'Y'
  end

  # This is where all the heavy lifting happens
  def process_repos
    stdout.out_success "Commit message: (used for the commit on each repo to describe the purpose of updating the '#{settings['target_submodule_name']}' submodule)."
    commit_message = strip_chars(gets.chomp(), ' "\'')
    # cleanup from the last build
    prep_build
    submodule_head_sha = determine_submodule_sha
    stdout.verbose("\nNow starting the process of all the repos you've chosen to update\n")
    @requested_repos.each do |repo_to_clone|
      stdout.out_success("\nProcessing repo: '#{repo_to_clone['name']}'")
      git.clone_repo_to(repo_to_clone['name'], settings['build_dir'])
      chdir_to_repo(repo_to_clone['name'])
      git.checkout_branch(repo_to_clone['branch'])
      submodule_relative_path = "#{repo_to_clone['submodule_dir']}/#{settings['target_submodule_name']}"
      if git.submodule_up_to_date(submodule_relative_path, submodule_head_sha)
        stdout.out_warn "The repo: #{repo_to_clone['name']} submodule #{settings['target_submodule_name']} is already up to date. Skipping"
      else
        pull_commit_submodule(repo_to_clone, commit_message)
      end
    end
    if repos_to_push.count > 0
      single_plural = repos_to_push.count == 1 ? 'Repo has been updated and is' : 'Repos have been updated and are'
      stdout.out_success "\n#{repos_to_push.count} #{single_plural} ready to push."
      stdout.out_success 'Starting confirmations to make actual pushes to Origin'
      repos_to_push.each do |repo|
        repo_path = "#{@settings['build_dir']}/#{repo['name']}"
        assert_path_exists repo_path, "Was cd'ing to the repo #{repo['name']} in order to push it to origin but the dir was not there??"
        chdir_to_repo repo['name']
        git.assert_known_branch repo['branch']
        if confirm_push(repo['name'], repo['branch'])
          git.push_to_origin(repo['name'], repo['branch'])
        else
          stdout.out_warn("Skipping push of repo #{repo['name']}")
        end
      end
    end
  end

  # get the current sha for the head of the target submodule branch
  def determine_submodule_sha
    stdout.out_success "\nFirst, I'll determine the sha for the HEAD of branch: '#{settings['target_submodule_target_branch']}'  for the submodule to be updated."
    stdout.out_success 'With that known, I can determine if a given repo is "Up to Date" for that particular submodule.'
    submodule_head_sha = get_sha_for_branch_origin_head
    stdout.out_success("\nDetermined [#{settings['target_submodule_name']}]'s branch [#{settings['target_submodule_target_branch']}]'s HEAD sha to be: #{submodule_head_sha}")
    submodule_head_sha
  end

  # get the sha of HEAD for origin/{target_branch}
  def get_sha_for_branch_origin_head
    git.clone_repo_to(settings['target_submodule_name'], settings['build_dir'])
    chdir_to_repo(settings['target_submodule_name'])
    git.checkout_branch(settings['target_submodule_target_branch'])
  end

  # Pull, then commit the submodule commits
  # @param [Hash] repo_to_clone
  # @param [String] commit_message
  def pull_commit_submodule(repo_to_clone, commit_message)
    submodule_path = "#{repo_to_clone['submodule_dir']}/#{settings['target_submodule_name']}"
    assert_path_exists(submodule_path, 'This is the expected path to the Saccharin submodule')
    git.init_submodule(submodule_path)
    chdir_to_repo_submodule(repo_to_clone, settings['target_submodule_name'])
    if confirm_pulls_from_origin
      git.pull_branch_origin_latest(settings['target_submodule_target_branch'])
      chdir_to_repo(repo_to_clone['name'])
      git.make_git_commit(commit_message, "#{repo_to_clone['submodule_dir']}/#{settings['target_submodule_name']}")
      repos_to_push << repo_to_clone
    else
      stdout.out_warn("Skipping processing of repo #{repo_to_clone['name']}")
    end
  end

  # Cleanup from previous runs of app.
  # Create any resources (dirs, etc) for the next build
  def prep_build
    stdout.out_success("\nPreparing build dir at: '#{settings['build_dir']}'")
    stdout.verbose("Removing build dir at: #{settings['build_dir']}")
    FileUtils.rm_rf(settings['build_dir'])
    # create the build dir
    stdout.verbose("Creating build dir at: #{settings['build_dir']}")
    FileUtils.mkdir(settings['build_dir'])
  end

  # Helper method to cd into the given (repo_name) repo dir.
  # @param [String] repo_name
  def chdir_to_repo(repo_name)
    repo_path = "#{settings['build_dir']}/#{repo_name}"
    assert_path_exists(repo_path, "This is the expected path to the repo: #{repo_name}")
    stdout.verbose("Changing to dir: #{repo_path}")
    FileUtils.chdir(repo_path)
    @repo_context      = repo_name
    @submodule_context = ''
  end

  # Helper method to cd into the given repo's submodule dir.
  # @param [Array] repo_meta
  # @param [String] target_submodule
  def chdir_to_repo_submodule(repo_meta, target_submodule)
    repo_submodule_path = "#{settings['build_dir']}/#{repo_meta['name']}/#{repo_meta['submodule_dir']}/#{target_submodule}"
    assert_path_exists(repo_submodule_path, "This is the expected path to the repo #{repo_meta['name']}'s' submodule: #{target_submodule}")
    stdout.verbose("Changing to dir: #{repo_submodule_path}")
    FileUtils.chdir(repo_submodule_path)
    @submodule_context = target_submodule
  end

  # Utility method to assert a filesystem path exists
  # @param [String] path
  # @param [String] additional_message
  def assert_path_exists(path, additional_message = '')
    if ! File.file? path and ! File.directory? path
      stdout.out_error "path [#{path}] does not exist"
      stdout.out_error additional_message
      exit 1
    end
  end

  # @param [String] string
  # @param [String] chars A string containing the chars to be stripped. i.e. ' "'
  def strip_chars(string, chars)
    string.gsub(/\A[#{chars}]+|[#{chars}]+\Z/, '')
  end

  # runs `git log HEAD..origin/{branch we are pulling from}`
  # this lets the client see the commits on origin that are about to
  # be pulled
  # @return [Boolean]
  def confirm_pulls_from_origin
    stdout.out_success("\nCommits on Origin that will be pulled\n")
    stdout.out git.show_git_log(nil, "HEAD..origin/#{settings['target_submodule_target_branch']}")
    stdout.out_success("#{context_prompt} Confirm pull? [y/N]")
    gets.chomp.upcase == 'Y'
  end


  def context_prompt
    "[#@repo_context:#@submodule_context]"
  end

end