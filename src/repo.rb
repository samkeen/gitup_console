class Repo
  attr_accessor :name, :target_branch, :submodules

  def initialize(options = {})
    @name          = options['name']
    @target_branch = options['branch']
    @submodules    = options['submodules']
  end

end