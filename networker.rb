#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

initialize_environment(ARGV)

puts '### Extracting directed network'

def reply_list(options = {})
  puts '# Assembling reply list'
  reply_array = []
  indent_stack = []
  indent_pointer = 0
  ThreadStore.all.each do |thread|
    thread.each do |post|
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > 0 and (!options[:window] or
          (TimeTools.in_time_window(options[:window], post[:time]) and
           TimeTools.in_time_window(options[:window], indent_stack[indent_pointer - 1][:time])))
        reply_array << [post[:user], indent_stack[indent_pointer - 1][:user]]
      end
    end
  end
  return reply_array
end

def shared_thread_list(options = {})
  puts '# Assembling shared thread list'
  shared_thread_list = []
  ThreadStore.all.each do |thread|
    users_list = []
    thread.each do |post|
      if !options[:window] or 
          TimeTools.in_time_window(options[:window], post[:time])
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

def network_hash(reply_list)
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

def to_pajek(network_hash, file_name, options = {})
  puts '# Saving as pajek'
  if options[:undirected]
    edges = "Edges"
  else
    edges = "Arcs"
  end

  keys = []
  network_hash.each_pair do |key1, hash|
    keys << key1
    hash.keys.each do |key2|
      keys << key2
    end
  end
  keys.sort!
  keys.uniq!

  keys_hash = {}
  i = 1
  keys.each do |key|
    keys_hash[key] = i
    i += 1
  end

  lines = ["*Vertices #{keys.size.to_s}"]
  keys.each do |key|
    lines << "#{keys_hash[key].to_s} \"#{key}\""
  end
  lines << "*#{edges}"
  network_hash.keys.sort.each do |key1|
    network_hash[key1].each_pair do |key2, weight|
      lines << "#{keys_hash[key1].to_s} #{keys_hash[key2].to_s} #{weight.to_s}"
    end
  end
  ForumTools::File.save_pajek(file_name, lines.join("\n") + "\n")
end

def do_replies(options = {})
  replies = reply_list(options)
  replies_network = network_hash(replies)
  if options[:window]
    to_pajek(replies_network, "w#{options[:window].to_s}_replies")
  else
    to_pajek(replies_network, "all_replies")
  end
end

def do_shareds(options = {})
  shareds = shared_thread_list(options)
  shareds_network = network_hash(shareds)
  if options[:window]
    to_pajek(shareds_network, "w#{options[:window].to_s}_shareds", :undirected => true)
  else
    to_pajek(shareds_network, "all_shareds", :undirected => true)
  end
end

puts '## All'
do_replies()
do_shareds()

TimeTools::WINDOWS.size.times do |i|
  puts "## Window #{i.to_s}"
  do_replies(:window => i)
  do_shareds(:window => i)
end
