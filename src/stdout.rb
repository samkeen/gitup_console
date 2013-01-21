# requirement: Ruby gem colorize
class Stdout

  attr_accessor :verbose_on

  # abstract sending STDOUT to console

  def initialize
    @type_color_map = {
        default: nil,
        success: :green,
        warn:    :yellow,
        error:   :red
    }
  end

  # send a default type message
  # @param [String] message
  def out(message)
    _out message, @type_color_map[:default]
  end

  # send a message with a specific color
  # @param [String] message
  # @param [Symbol] color
  def out_color(message, color)
    _out message, color
  end

  # send a success type message
  # @param [String] message
  def out_success(message)
    _out message, @type_color_map[:success]
  end

  # send a warn type message
  # @param [String] message
  def out_warn(message)
    _out message, @type_color_map[:warn]
  end

  # send and error type message
  # @param [String] message
  def out_error(message)
    _out message, @type_color_map[:error]
  end

  private
  # @param [String] message
  # @param [Symbol] color one of values in @type_color_map
  def _out(message, color=nil)
    if color.nil?
      puts message
    else
      puts message.colorize color
    end
  end
end