class Repo
  # To change this template use File | Settings | File Templates.

  attr_accessor :branches

  def initialize(name, clone_uri, build_dir, commander, stdout)
    @clone_uri = clone_uri
    @name      = name
    @build_dir = build_dir
    @commander = commander
    @stdout    = stdout
  end

  def clone
    clone_target_path = "#@build_dir/#@name"
    clone_cmd         = "git clone #@clone_uri #{clone_target_path}"
    @stdout.verbose("Cloning Repo: '#@name' to: '#{clone_target_path}'")
    @stdout.verbose @commander.run_command(clone_cmd)
  end

  def head_sha_for_branch(branch_name)
    branches[branch_name]
  end

end

#repo = Repo.new(name, clone_uri, build_dir, commander, stdout)
#repo.clone
#sha = repo.head_sha_for_branch('origin/master')