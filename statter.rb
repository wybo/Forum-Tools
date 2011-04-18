#!/usr/bin/ruby
require 'config'
require 'stores'
require 'time_tools'

puts '### Gathering statistics'

SLOW = false

def simple
  puts '# Listings'

  puts 'Posts for each thread'
  threads = ThreadStore.all()
  posts_for_each_thread = []
  threads.each do |thread|
    posts_for_each_thread << thread.size
  end
  ForumTools::File.save_stat("posts_for_each_thread", ["posts"].concat(posts_for_each_thread))

  puts 'Width for each thread'
  width_for_each_thread = []
  threads.each do |thread|
    post_with_max_indent = thread.max {|a, b| a[:indent] <=> b[:indent]}
    width_for_each_thread << post_with_max_indent[:indent]
  end
  ForumTools::File.save_stat("width_for_each_thread", ["width"].concat(width_for_each_thread))

  puts 'Posts for each user'
  
  users = UsersStore.new()
  posts_for_each_user = users.collect {|user| user[:posts]}.sort.reverse
  ForumTools::File.save_stat("posts_for_each_user", ["posts"].concat(posts_for_each_user))

  puts '# Totals'

  puts 'Threads'
  ForumTools::File.save_stat("total_threads", ["threads", threads.size])

  puts 'Posts'
  all_posts = []
  threads.each do |thread|
    thread.each do |post|
      all_posts << post
    end
  end
  ForumTools::File.save_stat("total_posts", ["posts", all_posts.size])

  puts 'Users'
  ForumTools::File.save_stat("total_users", ["users", users.size])
end

def over_time
  puts '# Threads over time'
  threads = ThreadStore.all()

  puts 'Threads for each hour'
  times = threads.collect {|thread| thread[0][:time]}
  threads_for_each_hour = TimeTools.per_period_adder(times, "hour")
  ForumTools::File.save_stat("threads_for_each_hour", ["threads"].concat(threads_for_each_hour))

  puts 'Daily'
  threads_for_each_day = TimeTools.per_period_adder(times, "day")
  ForumTools::File.save_stat("threads_for_each_day", ["threads"].concat(threads_for_each_day))

  puts '# Posts over time'
  puts 'Hourly'
  all_posts = []
  threads.each do |thread|
    thread.each do |post|
      all_posts << post
    end
  end
  times = all_posts.collect {|post| post[:time]}
  posts_for_each_hour = TimeTools.per_period_adder(times, "hour")
  ForumTools::File.save_stat("posts_for_each_hour", ["posts"].concat(posts_for_each_hour))

  puts 'Daily'
  posts_for_each_day = TimeTools.per_period_adder(times, "day")
  ForumTools::File.save_stat("posts_for_each_day", ["posts"].concat(posts_for_each_day))
end

def per_user_over_time
  puts '# Per user posts'
  threads = ThreadStore.all()
  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  times_for_each_prolific_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if prolific_user_hash[post[:user]]
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
    posts_per_hour_for_each_prolific_user[user] = TimeTools.per_period_adder(times, "hour")
  end
  ForumTools::File.save_stat("posts_per_hour_for_each_prolific_user",
      columnize_users_hash(posts_per_hour_for_each_prolific_user))

  puts 'Aligned posts per hour for each prolific user'
  aligned_posts_per_hour_for_each_prolific_user = {}
  users.each do |user|
    if prolific_user_hash[user[:name]]
      hour_counts = posts_per_hour_for_each_prolific_user[user[:name]]
      aligned_posts_per_hour_for_each_prolific_user[user[:name]] = 
          hour_counts[(user[:peak_window] - 24)..-1].concat(hour_counts[0...user[:peak_window]])
    end
  end
  ForumTools::File.save_stat("aligned_posts_per_hour_for_each_prolific_user",
      columnize_users_hash(aligned_posts_per_hour_for_each_prolific_user))
end

def measures
  puts "# Distance measures"
  puts "Time between posts and each reply"
  threads = ThreadStore.all()
  time_between_posts_and_each_reply = []
  indent_stack = []
  indent_pointer = 0
  threads.each do |thread|
    thread.each do |post|
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > 1
        time_between_posts_and_each_reply << 
            post[:time] - indent_stack[indent_pointer - 1][:time]
      end
    end
  end
  ForumTools::File.save_stat("time_between_posts_and_each_reply",
      ["time"].concat(time_between_posts_and_each_reply))

  if SLOW
  puts "Median circadian distance between users posts"
  times_for_each_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if !times_for_each_user_hash[post[:user]]
        times_for_each_user_hash[post[:user]] = []
      end
      times_for_each_user_hash[post[:user]] << TimeTools.second_of_day(post[:time])
    end
  end
  median_circadian_distance_between_users_posts = []
  users = UsersStore.new()
  users.each do |user1|
    users.each do |user2|
      differences = []
      times_for_each_user_hash[user1[:name]].each do |time1|
        times_for_each_user_hash[user2[:name]].each do |time2|
          differences << TimeTools.circadian_difference(time1 - time2)
        end
      end
      median_circadian_distance_between_users_posts <<
          calculate_median(differences.sort)
    end
  end
  ForumTools::File.save_stat("median_circadian_distance_between_users_posts",
      ["time"].concat(median_circadian_distance_between_users_posts))
  end

  puts "Distance between each user in networks"
  ForumTools::File::PajekFiles.all.each do |network_file|
    reply_distance_between_users = []
    matrix = `helper_scripts/shortest_distances.r #{network_file}`
    rows = matrix.split("\n")
    rows.collect! { |r| r.strip.squeeze(" ").split(" ") }
    rows.each do |cells|
      cells.each do |cell|
        reply_distance_between_users << cell
      end
    end
    ForumTools::File.save_stat("reply_distance_between_users.#{File.basename(network_file, ".net")}",
        ["distance"].concat(reply_distance_between_users))
  end
end

### Helper methods

def columnize_users_hash(user_hash)
  columns = []
  user_hash.keys.sort.each do |user|
    columns << [user].concat(user_hash[user])
  end
  return columns
end

def calculate_median(array)
  mid = (array.length - 1) / 2
  if array.length % 2 == 0
    mid2 = (array.length) / 2
    return ((array[mid] + array[mid2]) / 2.0).to_i
  else
    return array[mid]
  end
end

initialize_environment(ARGV)

simple()
over_time()
per_user_over_time()
measures()
