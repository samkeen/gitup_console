# simple view model
class ReportResults
  attr_accessor :need_to_update, :log_lines_lookup, :settings,
                :processed_repos

  # @param [Hash] up_to_date_modules
  # @param [Hash] need_to_update
  # @param [Hash] log_lines_lookup
  # @param [Hash] settings
  def initialize(up_to_date_modules, need_to_update, log_lines_lookup, settings)
    @up_to_date_modules = up_to_date_modules
    @need_to_update     = need_to_update
    @log_lines_lookup   = log_lines_lookup
    @settings           = settings
    _process
  end

  def get_bindings
    binding
  end

  def _process
    @processed_repos = {}
    settings['known_repos'].each do |repo|
      @processed_repos[repo['name']] = {:status => @up_to_date_modules.include?(repo['name']) ? :current : :outdated}
    end
  end

end