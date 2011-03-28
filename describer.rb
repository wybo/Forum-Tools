#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/lib")
require 'stores'
require 'h_o_t_tools'

HNTools.config(:root_dir => "/home/wybo/projects/hnscraper/data/")

puts '### Gathering descriptives'

def simple
  puts '# Listings'

  puts 'Posts for each thread'
  threads = ThreadStore.all()
  posts_for_each_thread = []
  threads.each do |thread|
    posts_for_each_thread << thread.size
  end
  HNTools::File.save_stat("posts_for_each_thread.dat", ["posts"].concat(posts_for_each_thread))

  puts 'Width for each thread'
  width_for_each_thread = []
  threads.each do |thread|
    post_with_max_indent = thread.max {|a, b| a[:indent] <=> b[:indent]}
    width_for_each_thread << post_with_max_indent[:indent]
  end
  HNTools::File.save_stat("width_for_each_thread.dat", ["width"].concat(width_for_each_thread))

  puts 'Posts for each user'
  posts_for_each_user_hash = get_posts_for_each_user(threads)
  posts_for_each_user = posts_for_each_user_hash.values.sort.reverse
  HNTools::File.save_stat("posts_for_each_user.dat", ["posts"].concat(posts_for_each_user))

  puts '# Totals'

  puts 'Threads'
  HNTools::File.save_stat("total_threads.dat", ["threads", threads.size])

  puts 'Posts'
  all_posts = []
  threads.each do |thread|
    thread.each do |post|
      all_posts << post
    end
  end
  HNTools::File.save_stat("total_posts.dat", ["posts", all_posts.size])

  puts 'Users'
  HNTools::File.save_stat("total_users.dat", ["users", posts_for_each_user_hash.keys.size])
end

def over_time
  puts '# Threads over time'
  threads = ThreadStore.all()

  puts 'Threads for each hour'
  times = threads.collect {|thread| thread[0][:time]}
  threads_for_each_hour = per_period_adder(times, "hour")
  HNTools::File.save_stat("threads_for_each_hour.dat", ["threads"].concat(threads_for_each_hour))

  puts 'Daily'
  threads_for_each_day = per_period_adder(times, "day")
  HNTools::File.save_stat("threads_for_each_day.dat", ["threads"].concat(threads_for_each_day))

  puts '# Posts over time'
  puts 'Hourly'
  all_posts = []
  threads.each do |thread|
    thread.each do |post|
      all_posts << post
    end
  end
  times = all_posts.collect {|post| post[:time]}
  posts_for_each_hour = per_period_adder(times, "hour")
  HNTools::File.save_stat("posts_for_each_hour.dat", ["posts"].concat(posts_for_each_hour))

  puts 'Daily'
  posts_for_each_day = per_period_adder(times, "day")
  HNTools::File.save_stat("posts_for_each_day.dat", ["posts"].concat(posts_for_each_day))
end

def per_user_over_time
  puts '# Per user daily peak'
  threads = ThreadStore.all()
  posts_for_each_user_hash = get_posts_for_each_user(threads)
  times_for_each_prolific_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if posts_for_each_user_hash[post[:user]] > 24
        if !times_for_each_prolific_user_hash[post[:user]]
          times_for_each_prolific_user_hash[post[:user]] = []
        end
        times_for_each_prolific_user_hash[post[:user]] << post[:time]
      end
    end
  end

  puts 'Posts per hour for each prolific user'
  posts_per_hour_for_each_prolific_user = {}
  times_for_each_prolific_user_hash.each_pair do |user, times|
    posts_per_hour_for_each_prolific_user[user] = per_period_adder(times, "hour")
  end
  HNTools::File.save_stat("posts_per_hour_for_each_prolific_user.dat",
      columnize_users_hash(posts_per_hour_for_each_prolific_user))

  puts 'Aligned posts per hour for each prolific user'
  aligned_posts_per_hour_for_each_prolific_user = {}
  posts_per_hour_for_each_prolific_user.each_pair do |user, hour_counts|
    max_index = hour_counts.index(hour_counts.max)
    new_hour_counts = hour_counts[(max_index - 24)..-1].concat(hour_counts[0...max_index])
    aligned_posts_per_hour_for_each_prolific_user[user] = new_hour_counts
  end
  HNTools::File.save_stat("aligned_posts_per_hour_for_each_prolific_user.dat",
      columnize_users_hash(aligned_posts_per_hour_for_each_prolific_user))
end

### Helper methods

def per_period_adder(times, hour_day)
  x_for_each_y = []
  if hour_day == "hour" # needed for hour alignments
    24.times do |i|
      x_for_each_y[i] = 0
    end
  end
  times.each do |time|
    period = HOTTools.send(hour_day, time)
    if !x_for_each_y[period]
      x_for_each_y[period] = 0
    end
    x_for_each_y[period] += 1
  end
  return x_for_each_y
end

def get_posts_for_each_user(threads)
  posts_for_each_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if !posts_for_each_user_hash[post[:user]]
        posts_for_each_user_hash[post[:user]] = 0
      end
      posts_for_each_user_hash[post[:user]] += 1
    end
  end
  return posts_for_each_user_hash
end

def columnize_users_hash(user_hash)
  columns = []
  user_hash.keys.sort.each do |user|
    columns << [user].concat(user_hash[user])
  end
  return columns
end

simple()
over_time()
per_user_over_time()
