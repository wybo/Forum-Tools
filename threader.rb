#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

puts '### Extracting directed network'

def thread_matrix(options = {})
  puts '# Assembling thread matrix'
  thread_matrix = []
  threads = get_threads(options)
  threads.each do |thread|
    i = 0
    start_time = thread[0][:time]
    thread.each do |post|
      if !thread_matrix[i]
        thread_matrix[i] = []
      end
      if !thread_matrix[i][post[:indent]] 
        thread_matrix[i][post[:indent]] = []
      end
      thread_matrix[i][post[:indent]] << post[:time] - start_time
      i += 1
    end
  end
  return thread_matrix
end

def prune_matrix(matrix, options = {})
  puts '# Pruning thread matrix'
  return matrix
end

def summarize_matrix(matrix, options = {})
  puts '# Summarizing matrix'
  matrix.collect! {|row|
    row.collect! {|cell|
      if cell
        cell = TimeTools.peak_window(cell) # array of times
      else
        cell = nil
      end
    }
  }
  return matrix
end

def colorize_matrix(matrix, options = {})
  puts '# Coloring matrix'
  matrix.collect! {|row|
    row.collect! {|cell|
      if cell
        cell = TimeTools.wheel_color_window(cell).join("") # window
      else
        cell = nil
      end
    }
  }
  return matrix
end

def unpack_to_thread(matrix, options = {})
  puts '# Unpacking to thread'
  diag_i = 0
  init_j = 0
  thread_array = []
  matrix.size.times do |diag_i|
    i = diag_i
    j = init_j
    if matrix[i] 
      while matrix[i] and matrix[i][j]
        thread_array << {:indent => j, :color => matrix[i][j] }
        i += 1
        j += 1
      end
      init_j = 1 # all indices start at 1 after first
    end
  end
  return thread_array
end

def get_threads(options = {})
  return ThreadStore.all()
end

def save_thread(file_infix, thread_array, options = {})
  puts '# Saving thread'
  options_string = ".tsort_#{options[:tsort].to_s}." + "collect_#{options[:collect].to_s}"
  thread = ThreadStore.new(:file_name => "#{file_infix}#{options_string}", :array => thread_array)
  thread.save_json()
end

def do_thread(options = {})
  thread_matrix = thread_matrix(options)
  pruned_matrix = prune_matrix(thread_matrix, options)
  summary_matrix = summarize_matrix(pruned_matrix, options)
  colored_matrix = colorize_matrix(summary_matrix, options)
  colored_thread = unpack_to_thread(colored_matrix)
  save_thread("thread_heat_map", colored_thread, options)
end

overall_options = {}
overall_options[:tsort] = false
args = ARGV.to_a
if args[0] == "tsort"
  overall_options[:tsort] = true
  args.delete_at(0)
end
if args[0] == "karma"
  overall_options[:collect] = :karma
  args.delete_at(0)
else
  overall_options[:collect] = :time
end

initialize_environment(args)

puts '## Creating thread heatmap'
do_thread(overall_options)
