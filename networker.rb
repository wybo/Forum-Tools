#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

puts '### Extracting directed network'

def reply_list(options = {})
  puts '# Assembling reply list'
  reply_array = []
  indent_stack = []
  indent_pointer = 0
  if options[:only_single_peak]
    users_hash = UsersStore.new().hash()
  end
  threads = get_threads(options)
  threads.each do |thread|
    thread.each do |post|
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > 0
        previous_post = indent_stack[indent_pointer - 1]
        if (!options[:window] or
            (TimeTools.in_time_window(options[:window], post[:time]) and
             TimeTools.in_time_window(options[:window], indent_stack[indent_pointer - 1][:time]))) and
           (!options[:only_single_peak] or
            (users_hash[post[:user]][:single_peak] and
             users_hash[previous_post[:user]][:single_peak]))
          reply_array << [post[:user], previous_post[:user]]
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
      if (!options[:window] or 
          TimeTools.in_time_window(options[:window], post[:time])) and
         (!options[:only_single_peak] or
          users_hash[post[:user]][:single_peak])
        users_list << post[:user]
      end
    end
    users_list.uniq!
    users_list.each do |user1|
      users_list.each do |user2|
        if user1 != user2 and user1 < user2
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

def undirect(network_hash)
  network_hash.keys.sort.each do |user1|
    network_hash[user1].keys.sort.each do |user2|
      if network_hash[user2] and network_hash[user2][user1]
        network_hash[user1][user2] += network_hash[user2][user1]
        network_hash[user2].delete(user1)
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

def prolific_prune(network_hash)
  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  network_hash.keys.each do |user1|
    if !prolific_user_hash[user1]
      network_hash.delete(user1)
    else
      network_hash[user1].keys.each do |user2|
        if !prolific_user_hash[user2]
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

PAJEK_COLORS = ["GreenYellow", "Yellow", "YellowOrange", "Orange", "RedOrange", "Red", 
          "OrangeRed", "Magenta", "Lavender", "Thistle", "Purple", "Violet",
          "Blue", "NavyBlue", "CadetBlue", "MidnightBlue", "Cyan", "Turquose",
          "BlueGreen", "Emerald", "SeaGreen", "Green", "PineGreen", "YellowGreen"]

WHEEL_PART_PART = []
4.times do |i|
  WHEEL_PART_PART << (255 / 4.0).ceil * i
end
8.times do
  WHEEL_PART_PART << 255
end
4.times do |i|
  WHEEL_PART_PART << 255 - (255 / 4.0).ceil * i
end
8.times do
  WHEEL_PART_PART << 0
end
WHEEL_PART = WHEEL_PART_PART.concat(WHEEL_PART_PART)
WHEEL_COLORS = []
24.times do |i|
  WHEEL_COLORS << [WHEEL_PART[i + 8], WHEEL_PART[i], WHEEL_PART[i - 8]]
end

def get_window_colors
  colors_hash = {}
  colors_hash[:pajek] = {}
  users = UsersStore.new()
  users.each do |user|
    colors_hash[:pajek][user[:name]] = ["ic", PAJEK_COLORS[user[:peak_window]], 
        "bc", PAJEK_COLORS[user[:peak_window]]]
  end
  colors_hash[:gexf] = {}
  users.each do |user|
    colors_hash[:gexf][user[:name]] = WHEEL_COLORS[user[:peak_window]]
  end
  return colors_hash
end

COORDINATES = []
24.times do |i|
  COORDINATES << [Math.cos(Math::PI / 12 * (i - 6)), Math.sin(Math::PI / 12 * (i + 6))]
end

def get_window_coordinates
  coordinates_hash = {}
  users = UsersStore.new()
  coordinates_hash[:pajek] = {}
  coordinates_hash[:gexf] = {}
  coordinates_hash[:graphml] = {}
  users.each do |user|
    coordinates = COORDINATES[user[:peak_window]]
    coordinates_hash[:pajek][user[:name]] = [coordinates[0] * 0.49 + 0.5, coordinates[1] * 0.49 + 0.5]
    coordinates_hash[:gexf][user[:name]] = [coordinates[0] * 1000, coordinates[1] * 1000]
    coordinates_hash[:graphml][user[:name]] = [coordinates[0] * 4950 + 5000, coordinates[1] * 4950 + 5000]
  end
  return coordinates_hash
end

def save_network(file_infix, network_hash, options = {})
  if options[:interaction_cutoff]
    cut = "interaction_" + options[:interaction_cutoff].to_s
  elsif options[:reciprocity_cutoff]
    cut = "reciprocity_" + options[:reciprocity_cutoff].to_s
  elsif options[:prolific_cutoff]
    cut = "prolific_" + options[:prolific_cutoff].to_s
  else
    cut = "false"
  end
  options_string = "cut_#{cut}.max_fr_#{options[:max_hours_on_frontpage].to_s}." +
      "singl_pk_#{options[:only_single_peak].to_s}.undr_#{options[:undirected].to_s}"
  if options[:window]
    ForumTools::File.save_networks("wnd_#{options[:window].to_s}#{options_string}_#{file_infix}", network_hash, options)
  else
    ForumTools::File.save_networks("all_#{options_string}_#{file_infix}", network_hash, options)
  end
end

def reduce(network_hash, options = {})
  if options[:interaction_cutoff]
    if options[:undirected] # undirected before cutoff
      network_hash = undirect(network_hash) 
    end
    network_hash = cutoff_prune(network_hash, options[:interaction_cutoff])
  elsif options[:reciprocity_cutoff]
    network_hash = cutoff_prune(network_hash, options[:reciprocity_cutoff])
    network_hash = reciprocity_prune(network_hash)
  elsif options[:prolific_cutoff]
    network_hash = prolific_cutoff(network_hash)
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

overall_options = {}
args = ARGV.to_a
if args[0] == "window"
  overall_options[:window] = true
  args.delete_at(0)
end
if args[0] == "shareds"
  overall_options[:shareds] = true
  args.delete_at(0)
end

initialize_environment(args)

overall_options.merge!(
    :interaction_cutoff => ForumTools::CONFIG[:interaction_cutoff],
    :reciprocity_cutoff => ForumTools::CONFIG[:reciprocity_cutoff],
    :prolific_cutoff => (ForumTools::CONFIG[:use_prolific_cutoff] ? ForumTools::CONFIG[:prolific_cutoff] : false),
    :max_hours_on_frontpage => ForumTools::CONFIG[:max_hours_on_frontpage],
    :only_single_peak => ForumTools::CONFIG[:only_single_peak],
    :undirected => ForumTools::CONFIG[:undirected]
)

if overall_options[:window]
  TimeTools::WINDOWS.size.times do |i|
    puts "## Window #{i.to_s}"
    overall_options[:window] = i
    do_replies(overall_options)
    do_shareds(overall_options) if overall_options[:shareds]
  end
else
  puts '## All'
  overall_options[:colors] = get_window_colors()
  overall_options[:coordinates] = get_window_coordinates()
  do_replies(overall_options)
  do_shareds(overall_options) if overall_options[:shareds]
end
