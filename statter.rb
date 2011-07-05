#!/usr/bin/ruby
require 'config'
require 'stores'
require 'time_tools'

puts '### Gathering statistics'

ARRIVALS_LEAVERS_GRACE = 30 * 24 * 3600

def simple
  puts '## Simple & totals'
  puts 'Posts for each thread'
  puts 'Width for each thread'
  puts 'Total threads'
  puts 'Total posts'
  posts_for_each_thread = []
  width_for_each_thread = []
  threads_counter = 0
  posts_counter = 0
  ThreadStore.all do |thread|
    posts_for_each_thread << thread.size
    post_with_max_indent = thread.max {|a, b| a[:indent] <=> b[:indent]}
    width_for_each_thread << post_with_max_indent[:indent]
    threads_counter += 1
    posts_counter += thread.size
  end
  posts_for_each_thread.sort!
  ForumTools::File.save_stat("posts_for_each_thread",
      ["posts"].concat(posts_for_each_thread))
  width_for_each_thread.sort!
  ForumTools::File.save_stat("width_for_each_thread",
      ["width"].concat(width_for_each_thread))
  ForumTools::File.save_stat("total_threads", ["threads", threads_counter])
  ForumTools::File.save_stat("total_posts", ["posts", posts_counter])

  puts 'Posts for each user'
  users = UsersStore.new()
  posts_for_each_user = users.collect {|user| user[:posts]}.sort.reverse
  ForumTools::File.save_stat("posts_for_each_user",
      ["posts"].concat(posts_for_each_user))

  puts 'Threads for each user'
  threads_for_each_user = users.collect {|user| user[:threads]}.sort.reverse
  ForumTools::File.save_stat("threads_for_each_user",
      ["threads"].concat(threads_for_each_user))

  puts 'Threads divided by posts for each user'
  threads_divided_by_posts_for_each_user = 
      users.collect {|user| (user[:threads] * 1.0) / user[:posts]}.sort.reverse
  ForumTools::File.save_stat("threads_divided_by_posts_for_each_user",
      ["threads"].concat(threads_divided_by_posts_for_each_user))

  puts 'Users'
  ForumTools::File.save_stat("total_users", ["users", users.size])
end

def over_time
  puts '## Over time'
  puts '# Overall'
  forums = ForumsStore.new()
  thread_times = []
  post_times = []
  ThreadStore.all do |thread|
    thread_times << thread[0][:time]
    thread.each do |post|
      post_times << post[:time]
    end
  end
  puts '# Total threads over time'
  over_time_for_each_time({"threads" => thread_times}, "total_threads", forums.start_time, forums.end_time)
  puts '# Total posts over time'
  over_time_for_each_time({"posts" => post_times}, "total_posts", forums.start_time, forums.end_time)
end

def over_time_per_user
  puts '## Over time per user'
  puts '# Over time for each user'
  puts '# Over time for each prolific user'

  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  thread_times_hash = {}
  prolific_thread_times_hash = {}
  post_times_hash = {}
  prolific_post_times_hash = {}
  ThreadStore.all do |thread|
    (thread_times_hash[thread[0][:user]] ||= []) << thread[0][:time]
    if prolific_user_hash[thread[0][:user]]
      (prolific_thread_times_hash[thread[0][:user]] ||= []) << thread[0][:time]
    end
    thread.each do |post|
      (post_times_hash[post[:user]] ||= []) << post[:time]
      if prolific_user_hash[post[:user]]
        (prolific_post_times_hash[post[:user]] ||= []) << post[:time]
      end
    end
  end
  forums = ForumsStore.new()
  puts 'sampling'
  sampled_thread_times_hash = ForumTools::Data.sample(
      thread_times_hash, 1500)
  thread_times_hash = nil
  sampled_post_times_hash = ForumTools::Data.sample(
      post_times_hash, 1500)
  post_times_hash = nil
  sampled_prolific_thread_times_hash = ForumTools::Data.sample(
      prolific_thread_times_hash, 20)
  prolific_thread_times_hash = nil
  sampled_prolific_post_times_hash = ForumTools::Data.sample(
      prolific_post_times_hash, 20)
  prolific_post_times_hash = nil
  puts '# Per sampled user threads over time'
  over_time_for_each_time(sampled_thread_times_hash, "user_threads", forums.start_time, forums.end_time)
  puts '# Per sampled user posts over time'
  over_time_for_each_time(sampled_post_times_hash, "user_posts", forums.start_time, forums.end_time)
  puts '# Per sampled prolific user threads over time'
  over_time_for_each_time(sampled_prolific_thread_times_hash, "sampled_prolific_user_threads", forums.start_time, forums.end_time)
  puts '# Per sampled prolific user posts over time'
  over_time_for_each_time(sampled_prolific_post_times_hash, "sampled_prolific_user_posts", forums.start_time, forums.end_time)
end

def over_time_per_forum
  puts '## For each forum'
  forums = ForumsStore.new()
  if forums.size > 1
    thread_times_hash = {}
    post_times_hash = {}
    forums.each do |forum|
      thread_times_hash[forum[:name]] = []
      post_times_hash[forum[:name]] = []
      ThreadStore.all(forum[:name]) do |thread|
        thread_times_hash[forum[:name]] << thread[0][:time]
        thread.each do |post|
          post_times_hash[forum[:name]] << post[:time]
        end
      end
    end
    puts '# Per forum threads over time'
    over_time_for_each_time(thread_times_hash, "forum_threads", forums.start_time, forums.end_time)
    puts '# Per forum posts over time'
    over_time_for_each_time(post_times_hash, "forum_posts", forums.start_time, forums.end_time)

    puts '## For each user per smallest, largest forums'
    thread_times_hash = {}
    post_times_hash = {}
    smallest_thread_times_hash, smallest_post_times_hash = add_up_forum_per_user(forums.smallest(20))
    largest_thread_times_hash, largest_post_times_hash = add_up_forum_per_user(forums.largest(5))
    puts '# Smallest forum per-user threads over time'
    over_time_for_each_time(smallest_thread_times_hash, "smallest_forum_user_threads", forums.start_time, forums.end_time)
    puts '# Smallest forum per-user posts over time'
    over_time_for_each_time(smallest_post_times_hash, "smallest_forum_user_posts", forums.start_time, forums.end_time)
    puts '# Largest forum per-user threads over time'
    over_time_for_each_time(smallest_thread_times_hash, "largest_forum_user_threads", forums.start_time, forums.end_time)
    puts '# Largest forum per-user posts over time'
    over_time_for_each_time(smallest_post_times_hash, "largest_forum_user_posts", forums.start_time, forums.end_time)
  end
end

def users_over_time
  puts '## Unique daily active users over time'
  forums = ForumsStore.new()
  unique_daily_user_times_hash = {}
  add_users_over_time_per_forum_times(:all, unique_daily_user_times_hash, forums.start_time)
  puts '# Users over time'
  over_time_circadian("day", {"users" => unique_daily_user_times_hash[:all]}, "unique_users")
  over_time_growth("day", {"users" => unique_daily_user_times_hash[:all]}, "unique_users", forums.start_time, forums.end_time)
end

def users_over_time_per_forum
  puts '## Users over time'
  forums = ForumsStore.new()
  if forums.size > 1
    unique_daily_user_times_hash = {}
    forums.each do |forum|
      add_users_over_time_per_forum_times(forum[:name], unique_daily_user_times_hash, forums.start_time)
    end
    puts '# Users over time per forum'
    over_time_circadian("day", unique_daily_user_times_hash, "unique_users_per_forum")
    over_time_growth("day", unique_daily_user_times_hash, "unique_users_per_forum", forums.start_time, forums.end_time)
  end
end

def add_users_over_time_per_forum_times(forum_name, unique_daily_user_times_hash, start_time)
  posted_on_day_array = []
  unique_daily_user_times_hash[forum_name] = []
  ThreadStore.all(forum_name) do |thread|
    thread.each do |post|
      day = TimeTools.day(post[:time], :start_time => start_time)
      if !posted_on_day_array[day]
        posted_on_day_array[day] = {}
      end
      if !posted_on_day_array[day][post[:user]]
        unique_daily_user_times_hash[forum_name] << post[:time]
        posted_on_day_array[day][post[:user]] = 1
      end
    end
  end
end

def left_after_one_post
  users = UsersStore.new()
  posted_once_hash = users.posted_once_hash()
  left_after_one_post_counter = 0
  forums = ForumsStore.new()
  cutoff = forums.end_time - ARRIVALS_LEAVERS_GRACE;
  ThreadStore.all do |thread|
    thread.each do |post|
      if posted_once_hash[post[:user]] and post[:time] < cutoff
        left_after_one_post_counter += 1
      end
    end
  end
  left_after_one_post_fraction = (left_after_one_post_counter * 1.0) / users.size
  ForumTools::File.save_stat("left_after_one_post", ["users", left_after_one_post_counter])
  ForumTools::File.save_stat("left_after_one_post_fraction", ["fraction", left_after_one_post_fraction])
end

def arrivals_leavers_over_time
  puts '## Arriving and leaving users over time'
  forums = ForumsStore.new()
  arrival_times_hash = {}
  leaver_times_hash = {}
  unique_daily_user_times_hash = {}

  add_arrivals_leavers_over_time_per_forum_times(:all, arrival_times_hash, leaver_times_hash,
      forums.start_time, forums.end_time)
  add_users_over_time_per_forum_times(:all, unique_daily_user_times_hash, forums.start_time)

  arriving_users_hash, leaving_users_hash,
  fraction_arriving_users_hash, fraction_leaving_users_hash,
  fraction_totaled_arriving_users_array, fraction_totaled_leaving_users_array =
      arrivals_leavers_over_time_per_forum_inner(arrival_times_hash, leaver_times_hash,
          unique_daily_user_times_hash, forums.start_time, forums.end_time)

  ForumTools::File.save_stat("arriving_users_growth_day",
      {"users" => arriving_users_hash[:all]},
      :add_case_numbers => true)
  ForumTools::File.save_stat("leaving_users_growth_day",
      {"users" => leaving_users_hash[:all]},
      :add_case_numbers => true)
  ForumTools::File.save_stat("arriving_users_fraction_of_previous_growth_day",
      {"fraction" => fraction_arriving_users_hash[:all]},
      :add_case_numbers => true)
  ForumTools::File.save_stat("leaving_users_fraction_of_previous_growth_day",
      {"fraction" => fraction_leaving_users_hash[:all]},
      :add_case_numbers => true)
  ForumTools::File.save_stat("arriving_users_totaled_fraction_of_previous_growth_day",
      {"fraction" => fraction_totaled_arriving_users_array})
  ForumTools::File.save_stat("leaving_users_totaled_fraction_of_previous_growth_day",
      {"fraction" => fraction_totaled_leaving_users_array})

end

def arrivals_leavers_over_time_per_forum
  puts '## Arriving and leaving users over time per forum'
  forums = ForumsStore.new()
  if forums.size > 1
    arrival_times_hash = {}
    leaver_times_hash = {}
    unique_daily_user_times_hash = {}

    forums.each do |forum|
      add_arrivals_leavers_over_time_per_forum_times(forum[:name], arrival_times_hash, leaver_times_hash,
          forums.start_time, forums.end_time)
      add_users_over_time_per_forum_times(forum[:name], unique_daily_user_times_hash, forums.start_time)
    end

    arriving_users_hash, leaving_users_hash,
    fraction_arriving_users_hash, fraction_leaving_users_hash,
    fraction_totaled_arriving_users_array, fraction_totaled_leaving_users_array =
        arrivals_leavers_over_time_per_forum_inner(arrival_times_hash, leaver_times_hash,
            unique_daily_user_times_hash, forums.start_time, forums.end_time)

    ForumTools::File.save_stat("arriving_users_per_forum_growth_day",
        arriving_users_hash,
        :add_case_numbers => true)
    ForumTools::File.save_stat("leaving_users_per_forum_growth_day",
        leaving_users_hash,
        :add_case_numbers => true)
    ForumTools::File.save_stat("arriving_users_fraction_of_previous_per_forum_growth_day",
        fraction_arriving_users_hash,
        :add_case_numbers => true)
    ForumTools::File.save_stat("leaving_users_fraction_of_previous_per_forum_growth_day",
        fraction_leaving_users_hash,
        :add_case_numbers => true)
    ForumTools::File.save_stat("arriving_users_totaled_fraction_of_previous_per_forum_growth_day",
        {"fractions" => fraction_totaled_arriving_users_array})
    ForumTools::File.save_stat("leaving_users_totaled_fraction_of_previous_per_forum_growth_day",
        {"fractions" => fraction_totaled_leaving_users_array})
  end
end

def arrivals_leavers_over_time_per_forum_inner(arrival_times_hash, leaver_times_hash, 
    unique_daily_user_times_hash, start_time, end_time)

  arriving_users_hash = calculate_over_time_growth("day", arrival_times_hash, start_time, end_time)
  leaving_users_hash = calculate_over_time_growth("day", leaver_times_hash, start_time, end_time)
  active_users_hash = calculate_over_time_growth("day", unique_daily_user_times_hash, start_time, end_time)

  fraction_arriving_users_hash = {}
  fraction_leaving_users_hash = {}
  fraction_totaled_arriving_users_array = []
  fraction_totaled_leaving_users_array = []
  active_users_hash.keys.each do |key|
    total_arriving_users_counter = 0
    total_leaving_users_counter = 0
    total_active_users_counter = 0
    fraction_arriving_users_hash[key] = [0]
    fraction_leaving_users_hash[key] = [0]
    active_users_hash[key].size.times do |i|
      if i > 0
        total_arriving_users_counter += arriving_users_hash[key][i]
        total_leaving_users_counter += leaving_users_hash[key][i]
        total_active_users_counter += active_users_hash[key][i - 1]
        if active_users_hash[key][i - 1] > 0
          fraction_arriving_users_hash[key][i] = (arriving_users_hash[key][i] * 1.0) / active_users_hash[key][i - 1]
          fraction_leaving_users_hash[key][i] = (leaving_users_hash[key][i] * 1.0) / active_users_hash[key][i - 1]
        else
          fraction_arriving_users_hash[key][i] = 0
          fraction_leaving_users_hash[key][i] = 0
        end
      end
    end
    fraction_totaled_arriving_users_array << (total_arriving_users_counter * 1.0) / total_active_users_counter
    fraction_totaled_leaving_users_array << (total_leaving_users_counter * 1.0) / total_active_users_counter
  end
  return [arriving_users_hash, leaving_users_hash, fraction_arriving_users_hash, fraction_leaving_users_hash,
      fraction_totaled_arriving_users_array, fraction_totaled_leaving_users_array]
end

def add_arrivals_leavers_over_time_per_forum_times(forum_name, arrival_times_hash, leaver_times_hash, start_time, end_time)
  arrival_times_hash[forum_name] = []
  leaver_times_hash[forum_name] = []
  threads = ThreadStore.all(forum_name)
  time_sorted_posts = get_time_sorted_posts(threads)
  add_x_over_time_times(time_sorted_posts, arrival_times_hash[forum_name], start_time, start_time + ARRIVALS_LEAVERS_GRACE)
  add_x_over_time_times(time_sorted_posts.reverse, leaver_times_hash[forum_name], end_time - ARRIVALS_LEAVERS_GRACE, end_time)
end

def add_x_over_time_times(time_sorted_posts, times_hash, exclude_start_time, exclude_end_time)
  posted_before_hash = {}
  time_sorted_posts.each do |post|
    if post[:time] > exclude_start_time and post[:time] < exclude_end_time
      posted_before_hash[post[:user]] = 1    
    elsif !posted_before_hash[post[:user]]
      times_hash << post[:time]
      posted_before_hash[post[:user]] = 1
    end
  end
end

def distance_between_posts
  forums = ForumsStore.new()
  if forums.size > 1
    forum_names = forums.collect {|f| f[:name]}
  else
    forum_names = [:all]
  end
  total_posts_counter = 0
  distance_array = []
  forum_names.each do |forum_name|
    per_user_posts_index_hash = {}
    threads = ThreadStore.all(forum_name)
    t = 0
    threads.each do |thread|
      i = 0
      thread.each do |post|
        if !per_user_posts_index_hash[post[:user]]
          per_user_posts_index_hash[post[:user]] = []
        end
        per_user_posts_index_hash[post[:user]] << {:index => i, :thread => t, :time => post[:time]}
        i += 1
        total_posts_counter += 1
      end
      t += 1
    end
    per_user_posts_index_hash.keys.each do |user|
      index_array = per_user_posts_index_hash[user]
      if index_array.size > 1
        index_array.sort! {|a, b| a[:time] <=> b[:time]}
        index_array.size.times do |i|
          if i > 0
            last_index = index_array[i - 1]
            index = index_array[i]
            if (last_index[:time] - index[:time]).abs < 3600 * 4 # different session if more than four hours apart
              if last_index[:thread] > index[:thread] or (last_index[:thread] == index[:thread] and last_index[:index] > index[:index])
                last_index, index = index, last_index
              end
              distance_array << calculate_distance_between_indices(threads, last_index, index)
            end
          end
        end
      end
    end
  end
  ForumTools::File.save_stat("distance_between_posts",
      {"distance" => distance_array})
  xin_session_posts_fraction = (distance_array.size * 1.0) / total_posts_counter
  ForumTools::File.save_stat("distance_between_posts_xin_session_posts_fraction",
      ["posts", xin_session_posts_fraction])
end

def calculate_distance_between_indices(threads, last_index, index)
  t_i = last_index[:thread]
  p_i = last_index[:index]
  counter = 0
  while t_i <= index[:thread]
    if t_i == index[:thread]
      p_i_end = index[:index]
    else
      p_i_end = threads[t_i].size - 1
    end
    p_i = 0
    while p_i <= p_i_end
      if threads[t_i][p_i][:time] < index[:time]
        counter += 1
      end
      p_i += 1
    end
    t_i += 1
  end
  return counter
end

def posts_later_than_x_threads # only meaningful for HN
  forums = ForumsStore.new()
  if forums.size > 1
    forum_names = forums.collect {|f| f[:name]}
  else
    forum_names = [:all]
  end
  total_posts_counter_array = []
  later_posts_counter_array = []
  forum_names.each do |forum_name|
    n_stack = []
    ThreadStore.all(forum_name) do |thread|
      n_stack.push(thread)
      if n_stack.size > 200
        n_stack.shift()
      end
      newest_time = n_stack[-1][0][:time]
      i = 0
      n_stack.reverse.each do |thread| # reversed
        thread.each do |post|
          if !total_posts_counter_array[i]
            later_posts_counter_array[i] = 0
            total_posts_counter_array[i] = 0
          end
          total_posts_counter_array[i] += 1
          if post[:time] >= newest_time
            later_posts_counter_array[i] += 1
          end
        end
        i += 1
      end
    end
  end
  later_posts_fraction_array = []
  total_posts_counter_array.size.times do |i|
    later_posts_fraction_array[i] = (later_posts_counter_array[i] * 1.0) / total_posts_counter_array[i]
  end
  ForumTools::File.save_stat("posts_fraction_later_than_x_threads",
      {"fraction" => later_posts_fraction_array},
      :add_case_numbers => true)
end

def thread_size_hours_over_time
  puts '## Average size per hour created'
  # Created here is the first time they appear on the homepage
  threads_average_size_per_hour_created = []
  ThreadStore.all do |thread|
    hour_created = TimeTools.hour(thread.on_frontpage_time)
    (threads_average_size_per_hour_created[hour_created] ||= []) << thread.size.to_f
  end
  threads_average_size_per_hour_created = collect_averages(threads_average_size_per_hour_created)
  ForumTools::File.save_stat("threads_average_size_per_hour_created",
      ["posts"].concat(threads_average_size_per_hour_created),
      :add_case_numbers => true)
end

def time_between_replies
  puts "## Time between replies"
  hours_between_replies = []
  indent_stack = []
  indent_pointer = 0
  ThreadStore.all do |thread|
    start_time = thread[0][:time]
    thread.each do |post|
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > 0 # both between story and replies and between replies
        last_post = indent_stack[indent_pointer - 1]
        if indent_pointer > 1 # only between replies
          # Time between
          add_difference(hours_between_replies, last_post[:time], post[:time])
        end
      end
    end
  end
  hours_between_replies.collect! { |h| h || 0 }
  ForumTools::File.save_stat("hours_between_replies",
      ["posts"].concat(hours_between_replies),
      :add_case_numbers => true)
end

def replying_tie_strength
  puts '## Replying per tie strength'
  threads = ThreadStore.all()
  time_sorted_posts = get_time_sorted_posts(threads)
  # Simple
  total_counter = 0
  # Additive, adds total & replies at that time
  total_users_replies_counter = 0
  total_totals_posts_counter = 0
  per_user_counter_hash = {}
  replies_counter_hash = {} # tracks number of replies made
  per_tie_strength_counter_hash = {"replies" => [], :total_users_replies => [], :total_totals_posts => []}
  time_sorted_posts.each do |post|
    if !post[:count_only]
      # Check for reciprocity
      if !replies_counter_hash[post[:user]]
        replies_counter_hash[post[:user]] = {}
      end
      if !replies_counter_hash[post[:user]][post[:prompted_by_user]]
        replies_counter_hash[post[:user]][post[:prompted_by_user]] = 0
      end
      tie_strength = replies_counter_hash[post[:user]][post[:prompted_by_user]]
      if tie_strength > 10 # cap at ten
        tie_strength = 10
      end
      if !per_tie_strength_counter_hash["replies"][tie_strength]
        per_tie_strength_counter_hash["replies"][tie_strength] = 0
        per_tie_strength_counter_hash[:total_users_replies][tie_strength] = 0
        per_tie_strength_counter_hash[:total_totals_posts][tie_strength] = 0
      end
      per_tie_strength_counter_hash["replies"][tie_strength] += 1
      per_tie_strength_counter_hash[:total_users_replies][tie_strength] += per_user_counter_hash[post[:prompted_by_user]] || 0 # must exist
      per_tie_strength_counter_hash[:total_totals_posts][tie_strength] += total_counter
      total_users_replies_counter += per_user_counter_hash[post[:prompted_by_user]] || 0
      total_totals_posts_counter += total_counter
      # Now record reply
      if !replies_counter_hash[post[:prompted_by_user]]
        replies_counter_hash[post[:prompted_by_user]] = {}
      end
      if !replies_counter_hash[post[:prompted_by_user]][post[:user]]
        replies_counter_hash[post[:prompted_by_user]][post[:user]] = 0
      end
      replies_counter_hash[post[:prompted_by_user]][post[:user]] += 1
    end
    total_counter += 1
    if !per_user_counter_hash[post[:user]]
      per_user_counter_hash[post[:user]] = 0
    end
    per_user_counter_hash[post[:user]] += 1
  end
  # Define additionals
  per_tie_strength_counter_hash["replies_fraction"] = []
  per_tie_strength_counter_hash["expected"] = []
  per_tie_strength_counter_hash["odds"] = []
  # Calculate additionals
  total_replies_sum = per_tie_strength_counter_hash["replies"].inject {|sum, x| sum + x}
  total_expected = (total_users_replies_counter * 1.0) / total_totals_posts_counter
  per_tie_strength_counter_hash["replies"].size.times do |i|
    per_tie_strength_counter_hash["replies_fraction"][i] = 
        (per_tie_strength_counter_hash["replies"][i] * 1.0) / total_replies_sum
    per_tie_strength_counter_hash["expected"][i] = 
        (per_tie_strength_counter_hash[:total_users_replies][i] * 1.0) / per_tie_strength_counter_hash[:total_totals_posts][i]
    per_tie_strength_counter_hash["odds"][i] =
        (per_tie_strength_counter_hash["expected"][i] * 1.0) / total_expected
  end
  per_tie_strength_counter_hash.delete(:total_users_replies)
  per_tie_strength_counter_hash.delete(:total_totals_posts)
  ForumTools::File.save_stat("replies_for_each_tie_strenght",
      per_tie_strength_counter_hash, :add_case_numbers => true)
end

def replying_over_time
  puts '## Replying over time'
  puts 'Time until post to any after reply, in thread vs overall'
  threads = ThreadStore.all()
  time_sorted_posts = get_time_sorted_posts(threads)
  last_received_replies_hash = {}
  after_reply_hours_until_post_hash = {"in_thread" => [], "out_thread" => [], "overall" => []}
  time_sorted_posts.each do |post|
    if !post[:count_only]
      if last_received_replies_hash[post[:user]]
        last_received_reply = last_received_replies_hash[post[:user]]
        add_after_reply_hours(after_reply_hours_until_post_hash, last_received_reply, post)
      end
      last_received_replies_hash[post[:prompted_by_user]] = post
    end
  end
  zero_pad_after_reply_hours(after_reply_hours_until_post_hash)
  ForumTools::File.save_stat("after_reply_hours_until_post",
      after_reply_hours_until_post_hash,
      :add_case_numbers => true)

  puts 'Time until reply to replyer, after reply, in thread vs overall'
  last_received_user_user_replies_hash = {}
  after_reply_hours_until_post_hash = {"in_thread" => [], "out_thread" => [], "overall" => []}
  time_sorted_posts.each do |post|
    if !post[:count_only]
      if last_received_user_user_replies_hash[post[:user].to_s + "&" + post[:prompted_by_user].to_s]
        last_received_reply = last_received_user_user_replies_hash[post[:user].to_s + "&" + post[:prompted_by_user].to_s]
        add_after_reply_hours(after_reply_hours_until_post_hash, last_received_reply, post)
      end
      last_received_user_user_replies_hash[post[:prompted_by_user].to_s + "&" + post[:user].to_s] = post
    end
  end
  zero_pad_after_reply_hours(after_reply_hours_until_post_hash)
  ForumTools::File.save_stat("after_reply_hours_until_reply_to_replyer",
      after_reply_hours_until_post_hash,
      :add_case_numbers => true)

  puts 'Time until reply to user posting after replyer, after reply, in thread vs overall'
  last_received_user_user_replies_hash = {}
  after_reply_hours_until_post_hash = {"in_thread" => [], "out_thread" => [], "overall" => []}
  i = 0
  time_sorted_posts.each do |post|
    if !post[:count_only]
      if last_received_user_user_replies_hash[post[:user].to_s + "&" + post[:prompted_by_user].to_s]
        last_received_reply = last_received_user_user_replies_hash[post[:user].to_s + "&" + post[:prompted_by_user].to_s]
        add_after_reply_hours(after_reply_hours_until_post_hash, last_received_reply, post)
      end
      next_post_in_thread = nil
      j = i + 1
      while !next_post_in_thread and j < time_sorted_posts.size
        # no need to check for count_only, as those are prompting thread opening posts only
        if time_sorted_posts[j][:thread_id] == post[:thread_id] and time_sorted_posts[j][:user] != post[:user]
          next_post_in_thread = time_sorted_posts[j]
        end
        j += 1
      end
      if next_post_in_thread
        last_received_user_user_replies_hash[post[:prompted_by_user].to_s + "&" + next_post_in_thread[:user].to_s] = post
      end
    end
    i += 1
  end
  zero_pad_after_reply_hours(after_reply_hours_until_post_hash)
  ForumTools::File.save_stat("after_reply_hours_until_reply_to_poster_after_replyer",
      after_reply_hours_until_post_hash,
      :add_case_numbers => true)
end

def add_after_reply_hours(after_reply_hours_until_post_hash, last_received_reply, post)
  if last_received_reply[:thread_id] == post[:thread_id]
    add_difference(after_reply_hours_until_post_hash["in_thread"], last_received_reply[:time], post[:time])
  else
    add_difference(after_reply_hours_until_post_hash["out_thread"], last_received_reply[:time], post[:time])
  end
  add_difference(after_reply_hours_until_post_hash["overall"], last_received_reply[:time], post[:time])
end

def zero_pad_after_reply_hours(after_reply_hours_until_post_hash)
  max_size = 0
  after_reply_hours_until_post_hash.keys.each do |key|
    if after_reply_hours_until_post_hash[key].size > max_size
      max_size = after_reply_hours_until_post_hash[key].size
    end
  end
  after_reply_hours_until_post_hash.keys.each do |key|
    max_size.times do |i|
      after_reply_hours_until_post_hash[key][i] ||= 0
    end
  end
end

def get_time_sorted_posts(threads)
  time_sorted_posts = []
  threads.each do |thread|
    indent_stack = []
    posts_hash = nil
    thread.each do |post|
      post[:thread_id] = thread[0][:id]
      if post[:replies_to]
        if !posts_hash
          posts_hash = thread.hash
        end
        post[:replies_to].each do |id|
          if !post[:prompted_by_user] and posts_hash[id] and posts_hash[id][:user] != post[:user]
            post[:prompted_by_user] = posts_hash[id][:user]
          end
        end
      elsif !indent_stack.empty? and indent_stack[post[:indent] - 1][:user] != post[:user] # self-replies are left out
        post[:prompted_by_user] = indent_stack[post[:indent] - 1][:user]
      end
      if !post[:prompted_by_user]
        post[:count_only] = true
      end
      time_sorted_posts << post
      indent_stack[post[:indent]] = post
    end
  end
  time_sorted_posts.sort! {|a, b| a[:time] <=> b[:time]}
  return time_sorted_posts
end

# TODO deal with flat threads
# TODO just reciprocated or not

#  threads = ThreadStore.all()
#  last_post = nil
#  threads.each do |thread|
#    received_replies_from_in_thread_hash = {}
#    thread.each do |post|
#      if !received_replies_from_in_thread_hash[post[:user]]
#        received_replies_from_in_thread_hash[post[:user]] = {}
#      end
#      if last_post and last_post[:user] != post[:user]
#        received_replies_from_in_thread_hash[last_post[:user]][post[:user]] = 1
#        if received_replies_from_in_thread_hash[post[:user]][last_post[:user]]
#          reply_to_replyer_in_thread += 1;
#        else
#          reply_to_other_in_thread += 1;
#        end
#      end
#      last_post = post
#    end
#  end

def add_up_forum_per_user(selected_forums)
  thread_times_hash = {}
  post_times_hash = {}
  selected_forums.each do |forum|
    ThreadStore.all(forum[:name]) do |thread|
      (thread_times_hash[forum[:name].to_s + "_" + thread[0][:user].to_s] ||= []) << thread[0][:time]
      thread.each do |post|
        (post_times_hash[forum[:name].to_s + "_" + post[:user].to_s] ||= []) << post[:time]
      end
    end
  end
  return [thread_times_hash, post_times_hash]
end

def over_time_for_each_time(times_hash, prefix, start_time, end_time)
  ["hour", "day"].each do |period|
    over_time_circadian(period, times_hash, prefix)
  end

  ["day", "week"].each do |period|
    over_time_growth(period, times_hash, prefix, start_time, end_time)
  end
end

def over_time_circadian(period, times_hash, prefix)
  for_each = calculate_over_time_circadian(period, times_hash)
  ForumTools::File.save_stat("#{prefix}_circadian_#{period}",
      for_each, :add_case_numbers => true)
end

def calculate_over_time_circadian(period, times_hash)
  puts "Circadian #{period}"
  for_each = {}
  times_hash.each_pair do |forum, times|
    for_each[forum] = TimeTools.per_period_adder(times, period)
  end
  return for_each
end

def over_time_growth(period, times_hash, prefix, start_time, end_time)
  for_each = calculate_over_time_growth(period, times_hash, start_time, end_time)
  ForumTools::File.save_stat("#{prefix}_growth_#{period}",
      for_each, :add_case_numbers => true)
end

def calculate_over_time_growth(period, times_hash, start_time, end_time)
  puts "Growth #{period}"
  for_each = {}
  times_hash.each_pair do |forum, times|
    for_each[forum] = TimeTools.per_period_adder(times, period, :start_time => start_time, :end_time => end_time)
  end
  return for_each
end

def time_on_frontpage
  puts '## Time on frontpage for each thread'
  threads = ThreadStore.all()
  hours_on_frontpage_for_each_thread = []
  threads.each do |thread|
    hours_on_frontpage = ((thread.off_frontpage_time - thread.on_frontpage_time) / 3600.0).to_i
    hours_on_frontpage_for_each_thread[hours_on_frontpage] ||= 0
    hours_on_frontpage_for_each_thread[hours_on_frontpage] += 1
  end
  ForumTools::File.save_stat("hours_on_frontpage_for_each_thread",
      ["threads"].concat(hours_on_frontpage_for_each_thread),
      :add_case_numbers => true)
end

def thread_hours_on_frontpage_per_hour_created
  puts '## Average hours on frontpage per hour created'
  threads_average_hours_on_frontpage_per_hour_created = []
  ThreadStore.all do |thread|
    hours_on_frontpage = ((thread.off_frontpage_time - thread.on_frontpage_time) / 3600.0)
    (threads_average_hours_on_frontpage_per_hour_created[hour_created] ||= []) << hours_on_frontpage
  end
  threads_average_hours_on_frontpage_per_hour_created = collect_averages(
      threads_average_hours_on_frontpage_per_hour_created)
  ForumTools::File.save_stat("threads_average_hours_on_frontpage_per_hour_created",
      ["hours"].concat(threads_average_hours_on_frontpage_per_hour_created),
      :add_case_numbers => true)
end

def average_ratings_over_time
  puts "## Ratings over time"
  puts "Average rating for comments per hour"
  puts "Average rating for threads per hour"
  puts "Average rating for comments per hour per weekday"
  average_comment_rating_per_hour = []
  average_thread_rating_per_hour = []
  average_comment_rating_per_hour_per_weekday = []
  threads = ThreadStore.all()
  threads.each do |thread|
    start_time = thread[0][:time]
    thread.each do |post|
      # Hourly
      hour = TimeTools.hour(post[:time])
      if post[:indent] == 0
        (average_thread_rating_per_hour[hour] ||= []) << post[:rating]
      else
        (average_comment_rating_per_hour[hour] ||= []) << post[:rating]
      end
      # Hour per week
      week_hour = TimeTools.week_hour(post[:time])
      if post[:indent] > 0
        (average_comment_rating_per_hour_per_weekday[week_hour] ||= []) << post[:rating]
      end
    end
  end
  average_comment_rating_per_hour = collect_averages(average_comment_rating_per_hour)
  ForumTools::File.save_stat("average_comment_rating_per_hour",
      ["rating"].concat(average_comment_rating_per_hour),
      :add_case_numbers => true)
  average_thread_rating_per_hour = collect_averages(average_thread_rating_per_hour)
  ForumTools::File.save_stat("average_thread_rating_per_hour",
      ["rating"].concat(average_thread_rating_per_hour),
      :add_case_numbers => true)
  average_comment_rating_per_hour_per_weekday = collect_averages(average_comment_rating_per_hour_per_weekday)
  ForumTools::File.save_stat("average_comment_rating_per_hour_per_weekday",
      ["rating"].concat(average_comment_rating_per_hour_per_weekday),
      :add_case_numbers => true)
end

def timezoned_per_user_over_time
  puts '## Per user posts'
  users = UsersStore.new()
  prolific_user_hash = users.prolific_hash()
  times_for_each_user_hash = {}
  ThreadStore.all do |thread|
    thread.each do |post|
      (times_for_each_user_hash[post[:user]] ||= []) << post[:time]
    end
  end

  puts 'Timezoned posts per hour for prolific users'
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
  ForumTools::File.save_stat("timezoned_posts_per_hour_for_sampled_prolific_users",
      sampled_timezoned_posts_per_hour_for_each_prolific_user,
      :add_case_numbers => true)

  puts 'Aggregate timezoned posts per hour'
  aggregate_timezoned_posts = []
  timezoned_posts_per_hour_for_each_user.each_pair do |user, counts|
    i = 0
    counts.each do |count|
      aggregate_timezoned_posts[i] ||= 0
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
      timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]] ||= []
      timezoned_posts_per_hour_for_each_timezone[users_hash[user][:timezone]][i] ||= 0
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

def add_difference(between_array, earlier, later)
  difference = ((later - earlier) / 3600.0).to_i
  if !between_array[difference]
    between_array[difference] = 0
  end
  between_array[difference] += 1
end

def average_ratings_after_time_level
  puts "## Average rating after time"
  average_rating_after_hours = []
  average_rating_per_level = []
  indent_stack = []
  indent_pointer = 0
  ThreadStore.all do |thread|
    start_time = thread[0][:time]
    thread.each do |post|
      indent_pointer = post[:indent]
      indent_stack[indent_pointer] = post
      if indent_pointer > 0 # both between story and replies and between replies
        # Average rating
        since_thread = ((post[:time] - start_time) / 3600.0).to_i
        (average_rating_after_hours[since_thread] ||= []) << post[:rating]
        # Rating per level
        level = post[:indent]
        (average_rating_per_level[level] ||= []) << post[:rating]
      end
    end
  end
  average_rating_after_hours = collect_averages(average_rating_after_hours)
  ForumTools::File.save_stat("average_rating_after_hours",
      ["rating"].concat(average_rating_after_hours),
      :add_case_numbers => true)
  ForumTools::File.save_stat("average_rating_per_level",
      ["rating"].concat(average_rating_per_level),
      :add_case_numbers => true)
end

def time_and_network_distances(options = {})
  puts "## Networks"
  puts "Pre-reading seconds of day at which posts are made"

  times_for_each_user_hash = {}
  ThreadStore.all do |thread|
    thread.each do |post|
      (times_for_each_user_hash[post[:user]] ||= []) << TimeTools.second_of_day(post[:time])
    end
  end

  differences_store = TimeDifferencesStore.new()
  NetworkStore.all_pajek_file_names.each do |network_file|
    base_name = File.basename(network_file)
    if false or
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
            differences_store[user1[:name]] ||= {}
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
  return NetworkStore.new(file_name, :keep_full_path => true)
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

def collect_averages(array)
  array.collect! {|items|
    if items
      ForumTools::Data.average(items)
    else
      nil
    end
  }
  return array
end

### Initialization

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
elsif args[0] == "hn"
  args.delete_at(0)
  initialize_environment(args)
  timezoned_per_user_over_time()
  thread_hours_on_frontpage_per_hour_created()
  average_ratings_over_time()
  average_ratings_after_time_level()
else
  initialize_environment(args)
#  simple()
#  over_time()
#  users_over_time()
#  over_time_per_user()
#  over_time_per_forum()

  users_over_time_per_forum()
  left_after_one_post()
  arrivals_leavers_over_time()
  arrivals_leavers_over_time_per_forum()
  distance_between_posts()
  posts_later_than_x_threads()

#  thread_size_hours_over_time()
#  time_between_replies()

  replying_tie_strength()
  replying_over_time()
end

# TODO consider what to do with posts per hour per user
