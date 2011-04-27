#!/usr/bin/ruby

# == Synopsis
#   Runner is a tool for running all steps of the data preparation
#
# == Usage
#   To run the default steps
#     ./runner.rb
#
#   To run with a specific task
#     ./runner.rb prepare
#
#   Other examples:
#     ./runner.rb -l
#     ./runner.rb prepare -l -e production
#
# == Options
#   <task-name>                      Selects task (optional)
#   -l, --list                       Lists the selected task and its steps
#                                    (or all if none selected)
#   -e, --environment <environment>  Sets the environment: test (default) 
#                                    or production
#   -h, --help                       Displays help message
#   -v, --version                    Display the version, then exit
#
# == Requirements
#   Ruby (inc rdoc, not included in Debian & Ubuntu, needs ruby and rdoc
#   packages there). Gems: nokogiri, chronos, active_support, open-uri, 
#   yaml
#
# == Copyright
#   Copyright (c) 2011 Wybo Wiersma. Licensed under the Affero GPL: 
#   http://www.fsf.org/licensing/licenses/agpl-3.0.html

require 'optparse'
require 'ostruct'
require 'rdoc/usage'

class Runner
  VERSION = '0.5.0'
  attr_reader :options

  TASKS = {
      :prepare => [
          "./parser.rb [<environment>]",
          "./networker.rb [<environment>]",
          "./networker.rb window [<environment>]",
          "./statter.rb [<environment>]"],
      :networks => [
          "./networker.rb [<mode>] standard",
          "./networker.rb [<mode>] standardmw"],
      :permutation => [
          "./networker.rb permutation [<environment>]",
          "./statter.rb permutation [<environment>]"],
      :user => [
          "./production/user_scraper.rb [<environment>]",
          "./parser.rb user [<environment>]"]
  }
  TASKS[:full] = TASKS[:prepare].dup.concat(TASKS[:user])
  TASKS[:sample] = ["./sampler.rb [<environment>]"].dup.concat(TASKS[:prepare])

  def initialize(arguments)
    @arguments = arguments

    # Set defaults
    @options = OpenStruct.new
    @options.environment = "test"
    @options.mode = nil
    @options.list = false
    @options.task = :sample
  end

  def run
    puts "### Runner version #{VERSION}"
    if parsed_options?
      output_options
      run_runner
    else
      output_usage
    end
  end

  protected

  def parsed_options?
    # Specify options
    opts = OptionParser.new
    opts.on('-e', '--environment <environment>') do |environment| 
      @options.environment = environment
    end
    opts.on('-m', '--mode <mode>') do |mode| 
      @options.mode = mode
    end

    opts.on('-l', '--list')        { @options.list = true }
    opts.on('-h', '--help')        { output_help }

    opts.parse!(@arguments) rescue return false
    if @arguments[0]
      @options.task = @arguments[0].to_sym
    end
    if TASKS[@options.task].nil?
      output_usage()
    end
    true
  end

  def output_options
    puts "# Options:"
      
    @options.marshal_dump.each do |name, val|        
      puts "#{name} = #{val}"
    end
  end

  def output_help
    output_version
    RDoc::usage() #exits app
  end

  def output_usage
    RDoc::usage('usage') # gets usage from comments above
  end

  def run_runner
    if @options.list
      tasks = TASKS
    else
      tasks = {@options.task => TASKS[@options.task]}
    end
    tasks = enter_arguments(tasks, 
        {:environment => @options.environment, :mode => @options.mode})
    process_tasks(tasks)
  end

  def process_tasks(tasks)
    puts "## Task#{(@options.list ? "(s) listing" : " running")}"
    tasks.keys.each do |task|
      puts "# Task: #{task}"
      tasks[task].each do |line|
        puts line
        if !@options.list
          system line
        end
      end
    end
  end

  def enter_arguments(tasks, arguments)
    tasks.keys.each do |task|
      tasks[task] = tasks[task].collect do |line|
        arguments.each_pair do |name, argument|
          if argument
            line.gsub!(/\[<#{name}>\]/, argument)
          else
            line.gsub!(/\[<#{name}>\] /, "")
          end
        end
        line
      end
    end
    return tasks
  end
end

# Create and run the application
runner = Runner.new(ARGV)
runner.run()
