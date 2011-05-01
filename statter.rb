#!/usr/bin/ruby
require 'config'
require 'stores'
require 'time_tools'

puts '### Gathering statistics'

SLOW = true

def simple
  puts '# Listings'

  puts 'Posts for each thread'
  threads = ThreadStore.all()
  posts_for_each_thread = []
  threads.each do |thread|
    posts_for_each_thread << thread.size
  end
  ForumTools::File.save_stat("posts_for_each_thread",
      ["posts"].concat(posts_for_each_thread))

  puts 'Width for each thread'
  width_for_each_thread = []
  threads.each do |thread|
    post_with_max_indent = thread.max {|a, b| a[:indent] <=> b[:indent]}
    width_for_each_thread << post_with_max_indent[:indent]
  end
  ForumTools::File.save_stat("width_for_each_thread",
      ["width"].concat(width_for_each_thread))

  puts 'Time on frontpage for each threads'
  time_on_frontpage_for_each_thread = []
  threads.each do |thread|
    time_on_frontpage = thread.off_frontpage_time - thread.on_frontpage_time
    time_on_frontpage_for_each_thread << time_on_frontpage
  end
  ForumTools::File.save_stat("time_on_frontpage_for_each_thread",
      ["width"].concat(width_for_each_thread))

  puts 'Posts for each user'
  users = UsersStore.new()
  posts_for_each_user = users.collect {|user| user[:posts]}.sort.reverse
  ForumTools::File.save_stat("posts_for_each_user",
      ["posts"].concat(posts_for_each_user))

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
  ForumTools::File.save_stat("threads_for_each_hour",
      ["threads"].concat(threads_for_each_hour),
      :add_case_numbers => true)

  puts 'Daily'
  threads_for_each_day = TimeTools.per_period_adder(times, "day")
  ForumTools::File.save_stat("threads_for_each_day",
      ["threads"].concat(threads_for_each_day),
      :add_case_numbers => true)

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
  ForumTools::File.save_stat("posts_for_each_hour",
      ["posts"].concat(posts_for_each_hour),
      :add_case_numbers => true)

  puts 'Daily'
  posts_for_each_day = TimeTools.per_period_adder(times, "day")
  ForumTools::File.save_stat("posts_for_each_day",
      ["posts"].concat(posts_for_each_day),
      :add_case_numbers => true)
end

def per_user_over_time
  puts '# Per user posts'
  threads = ThreadStore.all()
  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  times_for_each_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if !times_for_each_user_hash[post[:user]]
        times_for_each_user_hash[post[:user]] = []
      end
      times_for_each_user_hash[post[:user]] << post[:time]
    end
  end

  puts 'Posts per hour for each prolific user'
  posts_per_hour_for_each_user = {}
  posts_per_hour_for_each_prolific_user = {}
  times_for_each_user_hash.each_pair do |user, times|
    times_per_hour = TimeTools.per_period_adder(times, "hour")
    posts_per_hour_for_each_user[user] = times_per_hour
    if prolific_user_hash[user]
      posts_per_hour_for_each_prolific_user[user] = times_per_hour
    end
  end
  sampled_posts_per_hour_for_each_prolific_user = ForumTools::Data.sample(
      posts_per_hour_for_each_prolific_user, 10)
#  ForumTools::File.save_stat("posts_per_hour_for_sampled_prolific_users",
#      columnize_users_hash(sampled_posts_per_hour_for_each_prolific_user),
#      :add_case_numbers => true)

  puts 'Timezoned posts per hour for users'
  timezoned_posts_per_hour_for_each_user = {}
  timezoned_posts_per_hour_for_each_prolific_user = {}
  users.each do |user|
    if user[:timezone]
      timezone_offset = TimeTools.timezone_offset(user[:timezone], times_for_each_user_hash[user[:name]][-1])
      hour_counts = posts_per_hour_for_each_user[user[:name]]
      timezoned_hour_counts = hour_counts[(timezone_offset - 24)..-1].concat(hour_counts[0...timezone_offset])
      timezoned_posts_per_hour_for_each_user[user[:name]] = timezoned_hour_counts
      if prolific_user_hash[user[:name]]
        timezoned_posts_per_hour_for_each_prolific_user[user[:name]] = timezoned_hour_counts
      end
    end
  end
  sampled_timezoned_posts_per_hour_for_each_prolific_user = ForumTools::Data.sample(
      timezoned_posts_per_hour_for_each_prolific_user, 10)
#  ForumTools::File.save_stat("timezoned_posts_per_hour_for_sampled_prolific_users",
#      columnize_users_hash(sampled_timezoned_posts_per_hour_for_each_prolific_user),
#      :add_case_numbers => true)

  puts 'Aggregate timezoned posts per hour'
  aggregate_timezoned_posts = []
  timezoned_posts_per_hour_for_each_user.each_pair do |user, counts|
    i = 0
    counts.each do |count|
      if !aggregate_timezoned_posts[i]
        aggregate_timezoned_posts[i] = 0
      end
      aggregate_timezoned_posts[i] += count
      i += 1
    end
  end
  ForumTools::File.save_stat("aggregate_timezoned_posts",
      ["posts"].concat(aggregate_timezoned_posts),
      :add_case_numbers => true)

  puts 'Aggregate timezoned posts per hour for each timezone'
  users_hash = users.hash()
  timezoned_posts_per_hour_for_each_timezone = {}
  timezoned_posts_per_hour_for_each_user.each_pair do |user, counts|
    i = 0
    counts.each do |count|
      if !timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]]
        timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]] = []
      end
      if !timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]][i]
        timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]][i] = 0
      end
      timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]][i] += count
      i += 1
    end
  end

  timezoned_posts_per_hour_for_each_timezone.each_pair do |timezone, counts|
    timezone_string = timezone.gsub("/", "_")
    ForumTools::File.save_stat("aggregate_timezoned_posts_for_#{timezone_string}",
        ["posts"].concat(counts),
        :add_case_numbers => true)
  end
end

def post_time_distances
  puts "# Distance measures"
  puts "Time between replies"
  puts "Average rating after time"
  puts "Number of replies per level"
  threads = ThreadStore.all()
  hours_between_replies = []
  average_rating_after_hours = []
  average_rating_per_level = []
  indent_stack = []
  indent_pointer = 0
  last_indent_pointer = 0
  threads.each do |thread|
    start_time = thread[0][:time]
    thread.each do |post|
      last_indent_pointer = indent_pointer
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > last_indent_pointer + 1 # fill gap due to a delete
        indent_stack[indent_pointer - 1] = indent_stack[last_indent_pointer]
      end
      while indent_stack[indent_pointer - 1][:id] > post[:id] and indent_pointer > 0 # if posts are deleted without gap, such as indent 1
        indent_pointer -= 1
      end
      if indent_pointer > 0 # both between story and replies and between replies
        last_post = indent_stack[indent_pointer - 1]
        if indent_pointer > 1 # only between replies
          # Time between
          difference = ((post[:time] - last_post[:time]) / 3600.0).to_i
          if !hours_between_replies[difference]
            hours_between_replies[difference] = 0
          end
          hours_between_replies[difference] += 1
        end
        last_post = indent_stack[indent_pointer - 1]
        # Average rating
        since_thread = ((post[:time] - start_time) / 3600.0).to_i
        if !average_rating_after_hours[since_thread]
          average_rating_after_hours[since_thread] = []
        end
        average_rating_after_hours[since_thread] << post[:rating]
        # Rating per level
        level = post[:indent]
        if !average_rating_per_level[level]
          average_rating_per_level[level] = []
        end
        average_rating_per_level[level] << post[:rating]
      end
    end
  end
  ForumTools::File.save_stat("hours_between_replies",
      ["posts"].concat(hours_between_replies),
      :add_case_numbers => true)
  average_rating_after_hours.collect! {|times|
    if times
      ForumTools::Data.average(times)
    else
      nil
    end
  }
  ForumTools::File.save_stat("average_rating_after_hours",
      ["rating"].concat(average_rating_after_hours),
      :add_case_numbers => true)
  ForumTools::File.save_stat("average_rating_per_level",
      ["rating"].concat(average_rating_per_level),
      :add_case_numbers => true)
end

def time_and_network_distances(options = {})
  puts "# Networks"
  puts "Pre-reading seconds of day at which posts are made"

  threads = ThreadStore.all()
  times_for_each_user_hash = {}
  threads.each do |thread|
    thread.each do |post|
      if !times_for_each_user_hash[post[:user]]
        times_for_each_user_hash[post[:user]] = []
      end
      times_for_each_user_hash[post[:user]] << TimeTools.second_of_day(post[:time])
    end
  end

  differences_store = TimeDifferencesStore.new()
  NetworkStore.all_pajek_file_names.each do |network_file|
    base_name = File.basename(network_file)
    #if base_name == "all_replies.cut_false.max_fr_50.singl_pk_false.undr_true.net"
    #if base_name == "all_replies.cut_reciprocity_3.max_fr_50.singl_pk_false.undr_true.net" or
      #  base_name == "all_replies.cut_unprolific_5.max_fr_50.singl_pk_false.undr_true.net"
    if false or
#        base_name == "all_replies.cut_interaction_4.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_2.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_unprolific_5.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_1.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_1.unprolific_15.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_1.unprolific_5.max_fr_50.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_3.max_fr_8.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_unprolific_5.max_fr_8.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.cut_reciprocity_3.max_fr_12.singl_pk_false.undr_true.net" or
#        base_name == "all_replies.replies_only.cut_reciprocity_2.max_fr_12.singl_pk_false.undr_true.net" or
        base_name == "all_replies.replies_only.cut_reciprocity_3.max_fr_12.singl_pk_false.undr_true.net" or
        false
      network = NetworkStore.new(network_file)
      reply_distance_between_users_hash = get_network_distances(network.users, network_file, options)

      puts "Median circadian distance between users posts"
      reply_distance_between_users = []
      median_circadian_distance_between_users_posts = []
      users = ForumTools::Data.sample(network.users, 1000)
      users_hash = UsersStore.new().hash
      users.collect! {|u| users_hash[u] }

      i = 0
      users.each do |user1|
        print "."
        print i if i % 100 == 0
        users.each do |user2|
          if user2[:name] < user1[:name]
            if !differences_store[user1[:name]]
              differences_store[user1[:name]] = {}
            end
            if !differences_store[user1[:name]][user2[:name]]
              differences = []
              times_for_each_user_hash[user1[:name]].each do |time1|
                times_for_each_user_hash[user2[:name]].each do |time2|
                  differences << TimeTools.circadian_difference(time1 - time2)
                end
              end
              differences_store[user1[:name]][user2[:name]] = ForumTools::Data.median(differences)
            end
            median_circadian_distance_between_users_posts << differences_store[user1[:name]][user2[:name]]
            reply_distance_between_users << reply_distance_between_users_hash[user1[:name]][user2[:name]]
          end
        end
        i += 1
      end
      print "\n"

      ForumTools::File.save_stat("distances_between_users.cut_hop_#{options[:hop_cutoff]}.#{File.basename(network.file_name, ".net")}",
          [["distance"].concat(reply_distance_between_users),
           ["time"].concat(median_circadian_distance_between_users_posts)])
      puts "Saved output, don't close yet"
    end
  end
#  differences_store.save
  puts "Done, saved time differences store"
end

def daylight_saving_time
  puts "Reading networks"
  network_before = read_dst_network("dst2weeksbefore")
  network_after = read_dst_network("dst2weeksafter")
  users_before = network_before.users
  users_after = network_after.users
  network_before = nil
  network_after = nil
  reply_distance_between_users_before_hash =
      get_network_distances(users_before, dst_pajek_file_dir_name("dst2weeksbefore"))
  reply_distance_between_users_after_hash =
      get_network_distances(users_after, dst_pajek_file_dir_name("dst2weeksafter"))

  puts "Reading networks again"
  network_before = read_dst_network("dst2weeksbefore")
  network_after = read_dst_network("dst2weeksafter")

  users_hash = UsersStore.new().hash
  users_before.collect! {|u| users_hash[u] }

  puts "Calculating"
  reply_distance_between_selected_users_before = []
  reply_distance_between_selected_users_after = []
  users_before.each do |user1|
    print "."
    users_before.each do |user2|
      if (user2[:name] < user1[:name]) and 
          ((user1[:timezone] == "America/Los_Angeles" and user2[:country] == "UK") or
           (user1[:country] == "UK" and user2[:timezone] == "America/Los_Angeles")) and
          (reply_distance_between_users_before_hash[user1[:name]] and
           reply_distance_between_users_before_hash[user1[:name]][user2[:name]] and
           !reply_distance_between_users_before_hash[user1[:name]][user2[:name]].kind_of?(String)) and
          (reply_distance_between_users_after_hash[user1[:name]] and
           reply_distance_between_users_after_hash[user1[:name]][user2[:name]] and
           !reply_distance_between_users_after_hash[user1[:name]][user2[:name]].kind_of?(String))
        reply_distance_between_selected_users_before << 
            reply_distance_between_users_before_hash[user1[:name]][user2[:name]]
        reply_distance_between_selected_users_after <<
            reply_distance_between_users_after_hash[user1[:name]][user2[:name]]
      end
    end
  end
  print "\n"

  puts "Before average: " + ForumTools::Data.average(reply_distance_between_selected_users_before).to_s
  puts "After average:" + ForumTools::Data.average(reply_distance_between_selected_users_after).to_s

  ForumTools::File.save_stat("distances_between_timezoned_users.#{File.basename(dst_pajek_file_name(), ".net")}",
    [["before"].concat(reply_distance_between_selected_users_before),
     ["after"].concat(reply_distance_between_selected_users_after)])
  puts "Saved output"
end

def network_stats
  puts "## Reciprocity and transitivity"
  puts "# For windows"
  reciprocities = []
  transitivities = []
  NetworkStore.all_pajek_file_names.sort.each do |network_file|
    base_name = File.basename(network_file)
    if base_name =~ /^wnd_/
      puts "Doing window " + base_name
      rec_tra_arr = get_reciprocity_transitivity(network_file)
      reciprocities << rec_tra_arr[0]
      transitivities << rec_tra_arr[1]
    end
  end

  ForumTools::File.save_stat("window_reciprocities",
      ["reciprocity"].concat(reciprocities),
      :add_case_numbers => true)

  ForumTools::File.save_stat("window_transitivities",
      ["transitivity"].concat(transitivities),
      :add_case_numbers => true)

  ForumTools::File.save_stat("max_window_reciprocity", ["reciprocity", reciprocities.max])
  ForumTools::File.save_stat("min_window_reciprocity", ["reciprocity", reciprocities.min])

  ForumTools::File.save_stat("max_window_transitivity", ["transitivity", transitivities.max])
  ForumTools::File.save_stat("min_window_transitivity", ["transitivity", transitivities.min])

  puts "# For the whole network"

  rec_tra_arr = get_reciprocity_transitivity(
      ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:net_dir] +
      "all_replies.cut_false.max_fr_50.singl_pk_false.undr_false.net")
  reciprocity = rec_tra_arr[0]
  transitivity = rec_tra_arr[1]

  ForumTools::File.save_stat("all_transitivity", ["transitivity", transitivity])
  ForumTools::File.save_stat("all_reciprocity", ["reciprocity", reciprocity])
end

def permutation_test
  puts "## Permutation test"
  permutation_test = PermutationTestStore.new()
  if !permutation_test.respond_to?(:original)
    permutation_test.original = {:reciprocity => 0.113007, :transitivity => 0.0161657}
  end
  last_file = nil
  PermutationTestStore.all_pajek_file_names.each do |network_file|
    if PermutationTestStore.file_number(network_file) == permutation_test.size
      print "."
      rec_tra_arr = get_reciprocity_transitivity(network_file)
      permutation_test << {:reciprocity => rec_tra_arr[0], :transitivity => rec_tra_arr[1]}
      last_file = network_file
    else
      print "old file "
    end
  end
  print "."
  puts "Testing"
  permutation_test.test()
  permutation_test.save
  results = permutation_test.results
  puts results.inspect
  puts "Removing permutation networks"
  if last_file
    PermutationTestStore.all_pajek_file_names.each do |network_file|
      FileUtils.rm(network_file)
    end
  end
  puts "Done"
end

### Helper methods

def get_reciprocity_transitivity(network_file)
  reciprocity_transitivity = `helper_scripts/network_measures.r #{network_file}`
  rec_tra_arr = reciprocity_transitivity.split(" ")
  rec_tra_arr.collect! {|a| a.to_f}
  return rec_tra_arr
end

def read_dst_network(environment)
  file_name = ForumTools::CONFIG[:root_dir] + environment + "/" +
      ForumTools::CONFIG[:var_dir] + dst_pajek_file_name()
  return NetworkStore.new(file_name, :keep_path => true)
end

def dst_pajek_file_dir_name(environment)
  return ForumTools::CONFIG[:root_dir] + environment + "/" +
      ForumTools::CONFIG[:net_dir] + dst_pajek_file_name()
end

def dst_pajek_file_name
  return "all_replies.cut_false.max_fr_50.singl_pk_false.undr_true.net"
end

def get_network_distances(users, pajek_file_name, options = {})
  puts "Network-distances between users"
  matrix = `helper_scripts/shortest_distances.r #{pajek_file_name}`
  return ForumTools::Data.matrix_string_to_hash(matrix, users, options)
end

def columnize_users_hash(user_hash)
  columns = []
  user_hash.keys.sort.each do |user|
    columns << [user].concat(user_hash[user])
  end
  return columns
end

args = ARGV.to_a
if args[0] == "dist"
  args.delete_at(0)
  initialize_environment(args)
  time_and_network_distances(:hop_cutoff => ForumTools::CONFIG[:hop_cutoff])
elsif args[0] == "dst"
  args.delete_at(0)
  initialize_environment(args)
  daylight_saving_time()
elsif args[0] == "network"
  args.delete_at(0)
  initialize_environment(args)
  network_stats()
elsif args[0] == "permutation"
  args.delete_at(0)
  initialize_environment(args)
  permutation_test()
else
  initialize_environment(args)
  simple()
  over_time()
  per_user_over_time()
  post_time_distances()
end
