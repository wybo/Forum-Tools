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

def undirect(network_hash)
  network_hash.keys.sort.each do |user1|
    network_hash[user1].keys.sort.each do |user2|
      if network_hash[user2] and network_hash[user2][user1]
        network_hash[user1][user2] += network_hash[user2][user1]
        network_hash[user2].delete(user2)
      end
    end
  end
  return delete_empty_hashes(network_hash)
end

def prune(network_hash, options = {})
  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  if options[:custom_cutoff]
    network_hash.keys.each do |user1|
      network_hash[user1].keys.each do |user2|
        if network_hash[user1][user2] < options[:custom_cutoff]
          network_hash[user1].delete(user2)
        end
      end
    end
  else
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

def do_replies(options = {})
  replies = reply_list(options)
  replies_network = network_hash(replies)
  save_network("replies", replies_network, options)
  undirected_replies_network = undirect(replies_network)
  pruned_undirected_replies_network = prune(undirected_replies_network, :custom_cutoff => ForumTools::CONFIG[:replies_cutoff])
  save_network("pruned_undirected_replies",
      pruned_undirected_replies_network, options.merge(:undirected => true))
end

def do_shareds(options = {})
  shareds = shared_thread_list(options)
  shareds_network = network_hash(shareds)
  save_network("shareds", shareds_network, options.merge(:undirected => true))
  pruned_shareds_network = prune(shareds_network, :custom_cutoff => ForumTools::CONFIG[:shareds_cutoff])
  save_network("pruned_shareds_network", pruned_shareds_network, options.merge(:undirected => true))
end

def save_network(file_infix, network_hash, options = {})
  if options[:window]
    ForumTools::File.save_pajek("w#{options[:window].to_s}_#{file_infix}", network_hash)
  else
    ForumTools::File.save_pajek("all_#{file_infix}", network_hash)
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

# TODO
# Drop those with less than 2 replies
# Make undirected, add up all, and again cut at 5 or so
