class Repo
  attr_reader :name, :target_branch, :submodules

  def initialize(options = {})
    @name          = options['name']
    @target_branch = options['branch']
    @submodules    = options['submodules'] || []
  end

end