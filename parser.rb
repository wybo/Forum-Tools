#!/usr/bin/ruby
require 'config'
require 'parsers'
require 'stores'
require 'time_tools'

puts '### Parsing Hacker News data'

def parse_threads
  puts '# Parsing threads from html'
  HNThreadParser.all.each do |thread|
    thread.save
  end
end

def parse_all_times
  puts '# Parsing times from html'
  store = AllTimesStore.new()
  store.clear()
  puts 'new comments:'
  HNCommentsParser.all.each do |comment|
    store.add_times(comment)
  end
  puts 'new threads:'
  HNIndexParser.all("newest*").each do |index|
    store.add_times(index)
  end
  store.save
end

def calculate_canonical_times
  puts '# Calculating canonical times (averages if more than 1 reading)'
  puts '...can take a while...'
  a_store = AllTimesStore.new()
  store = a_store.to_canonical_times()
  store.save
end

def update_thread_post_times
  puts '# Estimating times for posts'
  store = TimesStore.new()
  ThreadStore.all.each do |thread|
    print "."
    thread.each do |post|
      post[:time] = store.time(post[:id])
      post.delete(:time_string)
    end
    thread.save
  end
  print "\n"
end

def set_on_frontpage_times
  puts '# Estimating when threads are on frontpage'
  puts 'reading index pages:'
  indices = HNIndexParser.all("index*")
  indices.sort {|x, y| x.save_time <=> y.save_time}
  puts 'estimating when on and off frontpage:'
  added_hash = {}
  on_done_hash = {}
  indices.each do |index|
    current_hash = {}
    print "."
    index.each do |thread|
      current_hash[thread[:id]] = 1
      if !on_done_hash[thread[:id]]
        full_thread = ThreadStore.new(thread[:id])
        full_thread.on_frontpage_time = index.save_time
        full_thread.save
        on_done_hash[thread[:id]] = 1
      end
    end
    added_hash.merge!(current_hash)
    added_hash.keys.each do |id|
      if !current_hash[id]
        thread = ThreadStore.new(id)
        thread.off_frontpage_time = index.save_time
        thread.save
        added_hash.delete(id)
      end
    end
  end
  print "\n"
end

def prune
  puts '# Removing incomplete data'
  end_time = ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym][:end_time].to_i
  ThreadStore.all.each do |thread|
    print "."
    delete = false
    if !thread.respond_to?(:on_frontpage_time) or thread.on_frontpage_time.nil? or
        !thread.respond_to?(:off_frontpage_time) or thread.off_frontpage_time.nil?
      delete = true
    end
    if thread.empty?
      delete = true
    end
    thread.each do |post|
      if !post[:time]
        delete = true
      end
    end
    if !delete and thread[0][:time] > end_time
      delete = true
    end
    if delete
      puts "\ndeleting " + thread.file_name
      thread.delete
    end
  end
  print "\n"
end

def parse_users
  puts '# Parsing users'
  puts 'from stores'
  times_for_each_user_hash = {}
  ThreadStore.all.each do |thread|
    thread.each do |post|
      if !times_for_each_user_hash[post[:user]]
        times_for_each_user_hash[post[:user]] = []
      end
      times_for_each_user_hash[post[:user]] << post[:time]
    end
  end
  peak_window_for_each_user = {}
  posts_per_hour_for_each_user = {}
  times_for_each_user_hash.each_pair do |user, times|
    peak_window_for_each_user[user] = TimeTools.peak_window(times)
    posts_per_hour_for_each_user[user] = TimeTools.per_period_adder(times, "hour")
  end
  other_for_each_user_hash = {}
  puts 'from html if available'
  HNUserParser.all.each do |user|
    other_for_each_user_hash[user.name] = user.to_hash
  end
  store = UsersStore.new()
  store_for_each_user_hash = store.hash
  store.clear()
  times_for_each_user_hash.each_pair do |name, times|
    peak_window = peak_window_for_each_user[name]
    if other_for_each_user_hash[name]
      user = other_for_each_user_hash[name]
    elsif store_for_each_user_hash[name]
      user = store_for_each_user_hash[name]
    else
      user = {}
    end
    user[:name] = name
    user[:posts] = times.size
    user[:peak_window] = peak_window
    user[:single_peak] = TimeTools.single_peak(peak_window, posts_per_hour_for_each_user[name])
    store << user
  end
  store.save
end

def parse_all
  parse_threads()
  parse_all_times()
  calculate_canonical_times()
  update_thread_post_times()
  set_on_frontpage_times()
  prune()
  parse_users()
end

args = ARGV.to_a
if args[0] == "user"
  args.delete_at(0)
  initialize_environment(args)
  parse_users()
else
  initialize_environment(args)
  parse_all()
end
