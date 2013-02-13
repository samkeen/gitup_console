module CommandLineArgs

  def usage_exit(script, options)
    puts "Usage\n"
    options_string = options.collect do |option_name, meta|
      meta[:keyval] ? "--#{option_name}=<value>" : "--#{option_name}"
    end
    puts "#{script} #{options_string.join(" ")}"
    exit 1
  end

# Command line option parsing.  There's a gem for this, but I wanted bootstrap to run gemless.
  def parse_cmd_line_args(script, options)
    if ARGV.length > 0
      ARGV.each do |arg|
        arg = arg.sub /^--/, ''
        if arg.match(/=/)
          arg_value_pair = arg.split /\=/
          arg = arg_value_pair[0]
          options[arg.to_sym][:value] = arg_value_pair[1]
        end
        if options.include? arg.to_sym
          options[arg.to_sym][:found] = true
        else
          print "#{arg.to_s} is an invalid option.\n"
          usage_exit(script, options)
        end
      end
    end
    ARGV.clear
    options
  end
end