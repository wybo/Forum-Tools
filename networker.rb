#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

COORDINATES = []
24.times do |i|
  COORDINATES << [Math.cos(Math::PI / 12 * (i - 6)), Math.sin(Math::PI / 12 * (i + 6))]
end
COORDINATES << [0, 0]

puts '### Extracting directed network'

def reply_list(options = {})
  puts '# Assembling reply list'
  reply_array = []
  indent_stack = []
  indent_pointer = 0
  last_indent_pointer = 0
  if options[:only_single_peak]
    users_hash = UsersStore.new().hash()
  end
  if options[:between_replies_only]
    minimum_pointer = 1
  else
    minimum_pointer = 0
    # both between thread prompts and comments and between comments
  end
  if options[:threads]
    threads = options[:threads]
  else
    threads = get_threads(options)
  end
  threads.each do |thread|
    thread.each do |post|
      last_indent_pointer = indent_pointer
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > last_indent_pointer + 1 # fill gap due to a delete
        indent_stack[indent_pointer - 1] = indent_stack[last_indent_pointer]
      end
      if indent_pointer > minimum_pointer
        previous_post = indent_stack[indent_pointer - 1]
        if (!options[:window] or TimeTools.in_time_window(options[:window], post[:time])) and
           (!options[:permutation_test] or options[:permutation_test].in_random_time_window(post[:time])) and
           (!options[:only_single_peak] or
            (users_hash[post[:user]][:single_peak] and
             users_hash[previous_post[:user]][:single_peak]))
          reply_array << [previous_post[:user], post[:user]]
        end
      end
    end
  end
  return reply_array
end

def shared_thread_list(options = {})
  puts '# Assembling shared thread list'
  shared_thread_list = []
  if options[:only_single_peak]
    users_hash = UsersStore.new().hash()
  end
  threads = get_threads(options)
  threads.each do |thread|
    users_list = []
    thread.each do |post|
      if (!options[:window] or TimeTools.in_time_window(options[:window], post[:time])) and
         (!options[:only_single_peak] or
          users_hash[post[:user]][:single_peak])
        users_list << post[:user]
      end
    end
    users_list.uniq!
    users_list.each do |user1|
      users_list.each do |user2|
        if user1 < user2
          shared_thread_list << [user1, user2] 
        end
      end
    end
  end
  return shared_thread_list
end

def network_hash(reply_list, options = {})
  puts '# Building network hash'
  network_hash = {}
  reply_list.each do |pair|
    if !network_hash[pair[0]]
      network_hash[pair[0]] = {}
    end
    if !network_hash[pair[0]][pair[1]]
      network_hash[pair[0]][pair[1]] = 0
    end
    network_hash[pair[0]][pair[1]] += 1
  end
  return network_hash
end

def circle_network_hash(reply_list, network_hash, options = {})
  puts '# Building circle hash'
  circle_network_hash = {}
  users_hash = UsersStore.new().hash()
  reply_list.each do |pair|
    if network_hash[pair[0]] and network_hash[pair[0]][pair[1]]
      if users_hash[pair[0]][:single_peak]
        window1 = users_hash[pair[0]][:peak_window]
      else
        window1 = 24
      end
      if users_hash[pair[1]][:single_peak]
        window2 = users_hash[pair[1]][:peak_window]
      else
        window2 = 24
      end
      if !circle_network_hash[window1]
        circle_network_hash[window1] = {}
      end
      if !circle_network_hash[window1][window2]
        circle_network_hash[window1][window2] = 0
      end
      circle_network_hash[window1][window2] += 1
    end
  end
  return circle_network_hash
end

def posts_circle_network_hash(network_hash, options = {})
  puts '# Building posts circle hash'
  posts_circle = {}
  indent_stack = []
  indent_pointer = 0
  last_indent_pointer = 0
  threads = get_threads(options)
  threads.each do |thread|
    thread.each do |post|
      last_indent_pointer = indent_pointer
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > last_indent_pointer + 1 # fill gap due to a delete
        indent_stack[indent_pointer - 1] = indent_stack[last_indent_pointer]
      end
      if indent_pointer > 0
        previous_post = indent_stack[indent_pointer - 1]
        if network_hash[previous_post[:user]] and network_hash[previous_post[:user]][post[:user]]
          window1 = TimeTools.hour(previous_post[:time])
          window2 = TimeTools.hour(post[:time])
          if !posts_circle[window1]
            posts_circle[window1] = {}
          end
          if !posts_circle[window1][window2]
            posts_circle[window1][window2] = 0
          end
          posts_circle[window1][window2] += 1
        end
      end
    end
  end
  return posts_circle
end

def dup_network(network_hash)
  new_network_hash = {}
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      if !new_network_hash[user1]
        new_network_hash[user1] = {}
      end
      new_network_hash[user1][user2] = network_hash[user1][user2]
    end
  end
  return new_network_hash
end

def undirect(network_hash)
  network_hash.keys.sort.each do |user1|
    network_hash[user1].keys.sort.each do |user2|
      if user1 < user2
        if network_hash[user2] and network_hash[user2][user1]
          network_hash[user1][user2] += network_hash[user2][user1]
          network_hash[user2].delete(user1)
        end
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def cutoff_prune(network_hash, cutoff)
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      if network_hash[user1][user2] < cutoff
        network_hash[user1].delete(user2)
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def prolific_prune(network_hash, prolific = true)
  users = UsersStore.new()
  if prolific
    prolificity_user_hash = users.prolific_hash()
  else
    prolificity_user_hash = users.unprolific_hash()
  end
  network_hash.keys.each do |user1|
    if !prolificity_user_hash[user1]
      network_hash.delete(user1)
    else
      network_hash[user1].keys.each do |user2|
        if !prolificity_user_hash[user2]
          network_hash[user1].delete(user2)
        end
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def reciprocity_prune(network_hash)
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      if !network_hash[user2] or !network_hash[user2][user1]
        network_hash[user1].delete(user2)
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def non_duplicate_prune(network_hash, remaining_network_hash)
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      if (!remaining_network_hash[user1] or !remaining_network_hash[user1][user2]) and 
         (!remaining_network_hash[user2] or !remaining_network_hash[user2][user1])
        network_hash[user1].delete(user2)
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def delete_empty_hashes(network_hash)
  network_hash.keys.each do |user|
    if network_hash[user].empty?
      network_hash.delete(user)
    end
  end
  return network_hash
end

def get_threads(options = {})
  if options[:max_hours_on_frontpage]
    return ThreadStore.max_hours_on_frontpage(options[:max_hours_on_frontpage])
  else
    return ThreadStore.all()
  end
end

def edge_windows(network_hash, options = {})
  puts '# Calculating edge windows'
  edge_times = {}
  indent_stack = []
  indent_pointer = 0
  last_indent_pointer = 0
  threads = get_threads(options)
  threads.each do |thread|
    thread.each do |post|
      last_indent_pointer = indent_pointer
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > last_indent_pointer + 1 # fill gap due to a delete
        indent_stack[indent_pointer - 1] = indent_stack[last_indent_pointer]
      end
      if indent_pointer > 0
        previous_post = indent_stack[indent_pointer - 1]
        if network_hash[previous_post[:user]] and network_hash[previous_post[:user]][post[:user]]
          if !edge_times[previous_post[:user]]
            edge_times[previous_post[:user]] = {}
          end
          if !edge_times[previous_post[:user]][post[:user]]
            edge_times[previous_post[:user]][post[:user]] = []
          end
          edge_times[previous_post[:user]][post[:user]] << post[:time]
        end
      end
    end
  end
  edge_times.keys.each do |user1|
    edge_times[user1].keys.each do |user2|
      edge_times[user1][user2] = TimeTools.peak_window(edge_times[user1][user2])
    end
  end
  return edge_times # edge_windows by now
end

def get_window_colors
  colors_hash = {}
  colors_hash[:pajek] = {}
  colors_hash[:gexf] = {}
  TimeTools::WHEEL_COLORS.size.times do |i|
    colors_hash[:pajek][i] = TimeTools.pajek_color_window(i)
    colors_hash[:gexf][i] = TimeTools.wheel_color_window(i) 
  end
  return colors_hash
end

def get_user_colors(options)
  colors_hash = {}
  colors_hash[:pajek] = {}
  colors_hash[:gexf] = {}
  users = UsersStore.new()
  users.each do |user|
    if user[:single_peak] and (!options[:single_peak_level] or user[:single_peak] == options[:single_peak_level])
      colors_hash[:pajek][user[:name]] = TimeTools.pajek_color_window(user[:peak_window])
      colors_hash[:gexf][user[:name]] = TimeTools.wheel_color_window(user[:peak_window])
    else
      colors_hash[:pajek][user[:name]] = TimeTools.pajek_color_window(24) # the grey
      colors_hash[:gexf][user[:name]] = TimeTools.wheel_color_window(24)
    end
  end
  return colors_hash
end

def get_edge_window_colors
  colors_hash = {}
  colors_hash[:pajek] = {}
  colors_hash[:gexf] = {}
  TimeTools::WHEEL_COLORS.size.times do |i|
    TimeTools::WHEEL_COLORS.size.times do |j|
      if !colors_hash[:pajek][i]
        colors_hash[:pajek][i] = {}
      end
      colors_hash[:pajek][i][j] = TimeTools.pajek_color_window(j)
      if !colors_hash[:gexf][i]
        colors_hash[:gexf][i] = {}
      end
      colors_hash[:gexf][i][j] = TimeTools.wheel_color_window(j)
    end
  end
  return colors_hash
end

def get_edge_colors(network_hash, edge_windows, options = {})
  colors_hash = {}
  colors_hash[:pajek] = {}
  colors_hash[:gexf] = {}
  users = UsersStore.new()
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      peak_window = edge_windows[user1][user2]
      if !colors_hash[:pajek][user1]
        colors_hash[:pajek][user1] = {}
      end
      colors_hash[:pajek][user1][user2] = TimeTools.pajek_color_window(peak_window)
      if !colors_hash[:gexf][user1]
        colors_hash[:gexf][user1] = {}
      end
      colors_hash[:gexf][user1][user2] = TimeTools.wheel_color_window(peak_window)
    end
  end
  return colors_hash
end

def get_edge_times(network_hash, edge_windows, options = {})
  times_hash = {}
  users = UsersStore.new()
  network_hash.keys.each do |user1|
    network_hash[user1].keys.each do |user2|
      peak_window = edge_windows[user1][user2]
      if !times_hash[user1]
        times_hash[user1] = {}
      end
      times_hash[user1][user2] = {:start => (peak_window * 3600), :end => ((peak_window + 2) * 3600)}
    end
  end
  return times_hash
end

def get_window_coordinates
  users = UsersStore.new()
  coordinates_hash = initialize_coordinates_hash()
  COORDINATES.size.times do |i|
    coordinates_hash = get_coordinates(i, i, coordinates_hash)
  end
  return coordinates_hash
end

def get_user_coordinates
  users = UsersStore.new()
  coordinates_hash = initialize_coordinates_hash()
  users.each do |user|
    coordinates_hash = get_coordinates(user[:peak_window], user[:name], coordinates_hash)
  end
  return coordinates_hash
end

def initialize_coordinates_hash
  coordinates_hash = {}
  coordinates_hash[:pajek] = {}
  coordinates_hash[:gexf] = {}
  coordinates_hash[:graphml] = {}
  return coordinates_hash
end

def get_coordinates(window, name, coordinates_hash)
  coordinates = COORDINATES[window]
  coordinates_hash[:pajek][name] = [coordinates[0] * 0.49 + 0.5, coordinates[1] * 0.49 + 0.5]
  coordinates_hash[:gexf][name] = [coordinates[0] * 1000, coordinates[1] * 1000]
  coordinates_hash[:graphml][name] = [coordinates[0] * 4950 + 5000, coordinates[1] * 4950 + 5000]
  return coordinates_hash
end

def get_node_weights(network_hash, file_name, options = {})
  puts "Betweenness-centrality for users"
  pajek_file_name = ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:net_dir] +
      ForumTools::File.set_extension(file_name, ".net")
  matrix = `helper_scripts/betweenness_centrality.r #{pajek_file_name}`
  network = NetworkStore.new(pajek_file_name)
  return {:gexf => ForumTools::Data.vector_string_to_hash(matrix, network.users, options)}
end

def save_network(file_infix, network_hash, options = {})
  if options[:interaction_cutoff]
    cut = "interaction_" + options[:interaction_cutoff].to_s
  elsif options[:reciprocity_cutoff]
    cut = "reciprocity_" + options[:reciprocity_cutoff].to_s
    if options[:unprolific_cutdown]
      cut += ".unprolific_" + options[:unprolific_cutdown].to_s
    end
  elsif options[:prolific_cutoff]
    cut = "prolific_" + options[:prolific_cutoff].to_s
  elsif options[:unprolific_cutdown]
    cut = "unprolific_" + options[:unprolific_cutdown].to_s
  else
    cut = "false"
  end
  if options[:between_replies_only]
    between = ".replies_only"
  else
    between = ""
  end
  if options[:node_weights]
    node_weights = ".wghts_" + options[:node_weights].to_s
  else
    node_weights = ""
  end
  if options[:single_peak_level]
    single_peak_level = ".singl_pk_level" + options[:single_peak_level].to_s
  else
    single_peak_level = ""
  end
  options_string = "#{node_weights}#{between}.cut_#{cut}.max_fr_#{options[:max_hours_on_frontpage].to_s}." +
      "singl_pk_#{options[:only_single_peak].to_s}#{single_peak_level}.undr_#{options[:undirected].to_s}"
  if options[:window]
    file_name = "wnd_#{sprintf("%02d", options[:window])}_#{file_infix}#{options_string}"
  else
    file_name = "all_#{file_infix}#{options_string}"
  end
  ForumTools::File.save_networks(file_name, network_hash, options)
  return file_name
end

def reduce(network_hash, options = {})
  if options[:interaction_cutoff]
    if options[:network] == "shareds" or !options[:undirected] # undirected before cutoff
      original_network_hash = dup_network(network_hash)
    else
      original_network_hash = nil
    end
    network_hash = undirect(network_hash) 
    network_hash = cutoff_prune(network_hash, options[:interaction_cutoff])
    if original_network_hash
      network_hash = non_duplicate_prune(original_network_hash, network_hash)
    end
  elsif options[:reciprocity_cutoff]
    network_hash = cutoff_prune(network_hash, options[:reciprocity_cutoff])
    network_hash = reciprocity_prune(network_hash)
    if options[:unprolific_cutdown]
      network_hash = prolific_prune(network_hash, false)
    end
  elsif options[:prolific_cutoff]
    network_hash = prolific_prune(network_hash)
  elsif options[:unprolific_cutdown]
    network_hash = prolific_prune(network_hash, false)
  end
  if options[:undirected]
    network_hash = undirect(network_hash) unless options[:interaction_cutoff]
  end
  return network_hash
end

def do_replies(options = {})
  replies = reply_list(options)
  replies_network = network_hash(replies, options)
  reduced_replies_network = reduce(replies_network, options)
  edge_windows = edge_windows(reduced_replies_network, options)
  options[:edge_colors] = get_edge_colors(reduced_replies_network, edge_windows, options)
  options[:edge_times] = get_edge_times(reduced_replies_network, edge_windows, options)
  if options[:node_weights]
    file_name = save_network("replies", reduced_replies_network, options)
    options[:weights] = get_node_weights(reduced_replies_network, file_name, options)
  end
  save_network("replies", reduced_replies_network, options)
end

def do_shareds(options = {})
  options = options.dup
  options[:undirected] = true
  shareds = shared_thread_list(options)
  shareds_network = network_hash(shareds, options)
  reduced_shareds_network = reduce(shareds_network, options)
  save_network("shareds", reduced_shareds_network, options)
end

def do_circle(options = {})
  options[:undirected] = false
  replies = reply_list(options)
  replies_network = network_hash(replies, options)
  reduced_replies_network = reduce(replies_network, options)
  replies_circle = circle_network_hash(replies, reduced_replies_network, options)
  save_network("circle", replies_circle, options)
end

def do_posts_circle(options = {})
  options[:undirected] = false
  replies = reply_list(options)
  replies_network = network_hash(replies, options)
  reduced_replies_network = reduce(replies_network, options)
  posts_circle = posts_circle_network_hash(reduced_replies_network, options)
  save_network("posts_circle", posts_circle, options)
end

def do_network(options = {})
  if options[:network] == "circle" or options[:network] == "posts_circle"
    options[:colors] = get_window_colors()
    options[:edge_colors] = get_edge_window_colors()
    options[:coordinates] = get_window_coordinates()
    if options[:network] == "posts_circle"
      do_posts_circle(options)
    else
      do_circle(options)
    end
  else
    options[:colors] = get_user_colors(options)
    options[:coordinates] = get_user_coordinates()
    if options[:network] == "shareds"
      do_shareds(options)
    else
      do_replies(options)
    end
  end
end

def do_permutation_test(options = {})
  threads = get_threads(options)
  options.merge!(:threads => threads)
  next_file_number = PermutationTestStore.next_file_number
  5000.times do |i|
    puts "Permutation #{next_file_number + i}"
    options[:permutation_test].randomize_windows
    replies = reply_list(options)
    replies_network = network_hash(replies, options)
    ForumTools::File.save_pajek(
        "x_random_window.#{sprintf("%05d", next_file_number + i)}.no_cuts",
        replies_network, options)
  end
end

overall_options = {}
args = ARGV.to_a
if args[0] == "window"
  overall_options[:window] = true
  args.delete_at(0)
elsif args[0] == "permutation"
  overall_options[:permutation_test] = true
  args.delete_at(0)
end
if args[0] == "shareds"
  overall_options[:network] = "shareds"
  args.delete_at(0)
elsif args[0] == "circle"
  overall_options[:network] = "circle"
  args.delete_at(0)
elsif args[0] == "posts_circle"
  overall_options[:network] = "posts_circle"
  args.delete_at(0)
end

initialize_environment(args)

overall_options.merge!(
    :interaction_cutoff => ForumTools::CONFIG[:interaction_cutoff],
    :reciprocity_cutoff => ForumTools::CONFIG[:reciprocity_cutoff],
    :prolific_cutoff => (ForumTools::CONFIG[:prolificity_prune] == :prolific ? ForumTools::CONFIG[:prolific_cutoff] : false),
    :unprolific_cutdown => (ForumTools::CONFIG[:prolificity_prune] == :unprolific ? ForumTools::CONFIG[:unprolific_cutdown] : false),
    :max_hours_on_frontpage => ForumTools::CONFIG[:max_hours_on_frontpage],
    :only_single_peak => ForumTools::CONFIG[:only_single_peak],
    :undirected => ForumTools::CONFIG[:undirected],
    :between_replies_only => ForumTools::CONFIG[:between_replies_only],
    :single_peak_level => ForumTools::CONFIG[:single_peak_level],
    :node_weights => ForumTools::CONFIG[:node_weights]
)

if overall_options[:window]
  TimeTools::WINDOWS.size.times do |i|
    puts "## Window #{i.to_s}"
    overall_options[:window] = i
    do_network(overall_options)
  end
elsif overall_options[:permutation_test]
  puts "## Networks from random windows"
  overall_options[:permutation_test] = PermutationTestStore.new()
  do_permutation_test(overall_options)
else
  puts '## All'
  do_network(overall_options)
end
