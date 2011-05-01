#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

puts '### Extracting directed network'

def thread_matrix(threads, options = {})
  puts '# Assembling thread matrix'
  thread_matrix = []
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
      if options[:collect] == :time
        thread_matrix[i][post[:indent]] << post[:time] - start_time
      else
        thread_matrix[i][post[:indent]] << post[:rating]
      end
      i += 1
    end
  end
  return thread_matrix
end

def prune_matrix(matrix, options = {})
  puts '# Pruning thread matrix'
  matrix.collect! {|row|
    row.collect! {|cell|
      if cell and cell.size >= 3 # array
        cell
      else
        cell = nil
      end
      cell
    }
  }
  return matrix
end

def summarize_matrix(matrix, options = {})
  puts '# Summarizing matrix'
  values = []
  matrix.collect! {|row|
    row.collect! {|cell|
      if cell
        if options[:collect] == :time
          cell = TimeTools.peak_window(cell) # array of times
   #       cell = ForumTools::Data.median(cell) # array of times
        else
          cell = ForumTools::Data.average(cell) # array of rating scores
        end
        values << cell
      else
        cell = nil
      end
      cell
    }
  }
  values.sort!
  jump = values.size / 24.0
  if options[:collect] == :rating
    matrix.collect! {|row|
      row.collect! {|cell|
        if cell
          i = 0
          while i < 23 and cell > values[(i * jump).to_i]
            i += 1
          end
          cell = i
        end
        cell
      }
    }
  end
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
        thread_array << {:indent => j, :value => matrix[i][j]}
        i += 1
        j += 1
      end
      init_j = 1 # all indices start at 1 after first
    end
  end
  return thread_array
end

def colorize_thread(thread, options = {})
  puts '# Coloring thread'
  thread.collect! {|post|
    colors = TimeTools.wheel_color_window(post[:value]) # window
    post[:color] = "#%02x%02x%02x" % colors
    post
  }
  return thread
end

def get_threads(options = {})
  return ThreadStore.all()
end

def time_sort_threads(threads)
  threads.collect! { |thread|
    sorted_arrays = add_to_nested_sorted_arrays(0, 0, thread)
    posts_list = peel_from_nested_arrays(sorted_arrays)
    thread.items = posts_list
    thread
  }
  return threads
end

def add_to_nested_sorted_arrays(previous_indent_pointer, index, thread)
  p_i_p = previous_indent_pointer
  nested_arrays = []
  i = index
  while i < thread.size
    post = thread[i]
    if post[:indent] > p_i_p
      nested_arrays << add_to_nested_sorted_arrays(post[:indent], i, thread)
    elsif post[:indent] == p_i_p
      nested_arrays << [post[:time], 1, post]
    else
      nested_arrays.sort! {|a, b| a[0] <=> b[0]}
      i_counter = nested_arrays.inject(0) {|c,a| c + a[1]}
      return [nested_arrays[0][0], i_counter].concat(nested_arrays)
    end
    i += nested_arrays[-1][1]
  end
  nested_arrays.sort! {|a, b| a[0] <=> b[0]}
  i_counter = nested_arrays.inject(0) {|c,a| c + a[1]}
  return [nested_arrays[0][0], i_counter].concat(nested_arrays)
end

def peel_from_nested_arrays(sorted_arrays)
  list = []
  sorted_arrays.each do |array_hash_or_int|
    if array_hash_or_int.kind_of?(Array)
      list.concat(peel_from_nested_arrays(array_hash_or_int))
    elsif array_hash_or_int.kind_of?(Hash)
      list << array_hash_or_int
    end # drop if int = time
  end
  return list
end

def select_original_threads(threads)
  selected_threads = []
  while selected_threads.size < 3
    thread = threads.choice
    if thread.size > 17 and thread.size < 21
    #if thread.size > 8 and thread.size < 12
      thread.collect! {|post|
        post[:value] = TimeTools.hour(post[:time] - thread[0][:time])
        post
      }
      selected_threads << thread
    end
  end
  return selected_threads
end

def save_thread(file_infix, thread_array, options = {})
  puts '# Saving thread'
  if !options[:colorize]
    no_colorize = ".colorize_false"
  else
    no_colorize = ""
  end
  options_string = ".tsort_#{options[:tsort].to_s}." + "collect_#{options[:collect].to_s}#{no_colorize}"
  thread = ThreadStore.new(:file_name => "#{file_infix}#{options_string}", :array => thread_array)
  thread.save_json(:variable => file_infix + options_string.gsub(".", "_"))
end

def do_original_threads(threads, options = {})
  selected_threads = select_original_threads(threads)
  i = 0
  selected_threads.each do |thread|
    if options[:colorize]
      thread = colorize_thread(thread, options)
    end
    save_thread("original_#{i}", thread, options)
    i += 1
  end
end

def do_thread(options = {})
  threads = get_threads(options)
  if options[:collect] == :original
    do_original_threads(threads, options)
  else
    threads.reject! {|t| t.size < 20}
    if options[:tsort]
      threads = time_sort_threads(threads)
    end
    thread_matrix = thread_matrix(threads, options)
    pruned_matrix = prune_matrix(thread_matrix, options)
    summary_matrix = summarize_matrix(pruned_matrix, options)
    summary_thread = unpack_to_thread(summary_matrix)
    if options[:colorize]
      summary_thread = colorize_thread(summary_thread, options)
    end
    save_thread("thread", summary_thread, options)
  end
end

overall_options = {}
overall_options[:tsort] = false
overall_options[:colorize] = true
args = ARGV.to_a
if args[0] == "tsort"
  overall_options[:tsort] = true
  args.delete_at(0)
end
if args[0] == "original"
  overall_options[:collect] = :original
  args.delete_at(0)
elsif args[0] == "rating"
  overall_options[:tsort] = true
  overall_options[:collect] = :rating
  args.delete_at(0)
else
  overall_options[:collect] = :time
end

initialize_environment(args)

puts '## Creating thread heatmap'
do_thread(overall_options)
