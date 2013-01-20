# requirement: Ruby gem colorize
class Stdout

  def initialize(verbose_on=false)
    @verbose_on = verbose_on
  end

  # abstract sending STDOUT to console
  @type_color_map = {
      default: nil,
      verbose: :cyan,
      success: :green,
      warn:    :yellow,
      error:   :red
  }

  # send a default type message
  def send(message)
    _out message, @type_color_map[:default]
  end

  # send a success type message
  # @param [String] message
  def send_success(message)
    _out message, @type_color_map[:success]
  end

  # send a warn type message
  # @param [String] message
  def send_warn(message)
    _out message, @type_color_map[:warn]
  end

  # send and error type message
  # @param [String] message
  def send_error(message)
    _out message, @type_color_map[:error]
  end

  private
  # @param [String] message
  # @param [Symbol] color one of values in @type_color_map
  def _out(message, color=nil)
    if color.nil?
      if @verbose_on
        puts message.colorize @type_color_map[:verbose]
      else
        puts message
      end
    else
      puts message.colorize color
    end
  end
end