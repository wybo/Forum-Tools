#!/usr/bin/ruby
require 'config'
require 'sioc_parsers'
require 'stores'
require 'time_tools'

puts '### Parsing SIOC (Boards.ie) data'

def parse_threads
  post_file_hash, thread_file_hash = get_file_names()

  puts '# Parsing threads and posts from xml'
  i = 0
  thread_file_hash.keys.sort.each do |thread_id|
    thread = SIOCThreadParser.new(thread_file_hash[thread_id])
    thread.each do |post|
      if post_file_hash[post[:id]]
        parsed_post = SIOCPostParser.new(post_file_hash[post[:id]])
        post.merge!(parsed_post.to_hash)
      else
        puts "post " + post[:id].to_s + " missing"
      end
    end
    print "."
    if i % 200 == 0
      print i
    end
    thread.save
    i += 1
  end
  print "\n"
  puts "Errors with:"
  puts SIOCParser.errors.join("\n")
end

def prune
  puts '# Removing incomplete data'
  ThreadStore.all do |thread|
    delete = false
    save = false
    print "."
    posts_to_delete = []
    thread.each do |post|
      delete_post = false
      if !post[:time]
        delete_post = true
      end
      if !post[:user]
        delete_post = true
      end
      if delete_post
        posts_to_delete.push(post)
        save = true
      end
    end
    posts_to_delete.each do |post|
      thread.array_delete(post)
    end
    if thread.empty?
      delete = true
    end
    if delete
      puts "\ndeleting " + thread.file_name
      thread.delete
    elsif save
      puts "\nsaving " + thread.file_name
      thread.save
    end
  end
  print "\n"
end

def parse_users
  puts '# Parsing users'
  threads_for_each_user_hash = {}
  posts_for_each_user_hash = {}
  ThreadStore.all do |thread|
    if !threads_for_each_user_hash[thread[0][:user]]
      threads_for_each_user_hash[thread[0][:user]] = 0
    end
    threads_for_each_user_hash[thread[0][:user]] += 1
    thread.each do |post|
      if !posts_for_each_user_hash[post[:user]]
        posts_for_each_user_hash[post[:user]] = 0
      end
      posts_for_each_user_hash[post[:user]] += 1
    end
  end
  store = UsersStore.new()
  store_for_each_user_hash = store.hash
  store.clear()
  posts_for_each_user_hash.each_pair do |name, count|
    if store_for_each_user_hash[name]
      user = store_for_each_user_hash[name]
    else
      user = {}
    end
    user[:name] = name
    user[:posts] = count
    user[:threads] = threads_for_each_user_hash[name] || 0
    store << user
  end
  store.save
end

def parse_forums
  puts '# Parsing forums'
  threads_for_each_forum_hash = {}
  posts_for_each_forum_hash = {}
  start_time_for_each_forum_hash = {}
  end_time_for_each_forum_hash = {}
  users_for_each_forum_hash = {}
  ForumsStore.all_forum_names().each do |forum_name|
    threads_for_each_forum_hash[forum_name] = 0
    posts_for_each_forum_hash[forum_name] = 0
    start_time_for_each_forum_hash[forum_name] = Time.now.to_i
    end_time_for_each_forum_hash[forum_name] = 0
    users_for_this_forum = {}
    ThreadStore.all(forum_name) do |thread|
      threads_for_each_forum_hash[forum_name] += 1
      if thread[0][:time] < start_time_for_each_forum_hash[forum_name]
        start_time_for_each_forum_hash[forum_name] = thread[0][:time]
      end
      thread.each do |post|
        posts_for_each_forum_hash[forum_name] += 1
        users_for_this_forum[post[:user]] = 1
        if post[:time] > end_time_for_each_forum_hash[forum_name]
          end_time_for_each_forum_hash[forum_name] = post[:time]
        end
      end
    end
    users_for_each_forum_hash[forum_name] = users_for_this_forum.keys.size
  end
  store = ForumsStore.new()
  store_for_each_forum_hash = store.hash
  store.clear()
  posts_for_each_forum_hash.each_pair do |name, count|
    if store_for_each_forum_hash[name]
      forum = store_for_each_forum_hash[name]
    else
      forum = {}
    end
    forum[:name] = name
    forum[:threads] = threads_for_each_forum_hash[name] || 0
    forum[:posts] = count
    forum[:start_time] = start_time_for_each_forum_hash[name]
    forum[:end_time] = end_time_for_each_forum_hash[name]
    forum[:users] = users_for_each_forum_hash[name] || 0
    store << forum
    store.sort! {|a,b| b[:users] <=> a[:users] } # reverse sort
    i = 0
    store.each do |forum|
      forum[:rank] = i
      i += 1
    end
  end
  store.save
end

def parse_all
#  parse_threads()
#  prune()
#  parse_users()
  parse_forums()
end

def rename_files
  post_file_hash, thread_file_hash = get_file_names()

  doit = false
  ThreadStore.all_forums.each do |forum|
    if forum.to_i == 47
      doit = true
    end
    if doit
      forum_dir = ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir] + forum
      FileUtils.mkdir_p(forum_dir)
      ThreadStore.all(forum) do |thread|
        if thread_file_hash[thread.id]
          page = 0
          thread_file_hash[thread.id].each do |file_name|
            print "."
            rename_file(file_name, forum_dir + "/" + "thread_#{thread.id}_#{page}.xml")
            page += 1
          end
        end
        thread.each do |post|
          if post_file_hash[post[:id]]
            rename_file(post_file_hash[post[:id]],
                forum_dir + "/" + "post_#{post[:id]}.xml")
          end
        end
      end
    end
  end
  print "\n"
end

### Helpers

def get_file_names
  post_file_hash = {}
  SIOCPostParser.all_file_names.each do |post_file_name|
    name_and_id = post_file_name.split("%3D")
    if name_and_id.size > 1
      post_id = name_and_id[-1].to_i
      post_file_hash[post_id] = post_file_name
    end
  end
  puts 'Got posts'

  thread_file_hash = {}
  SIOCThreadParser.all_file_names.each do |thread_file_name|
    thread_and_page = thread_file_name.split("%26page%3D")
    if thread_and_page.size > 1
      page = thread_and_page[-1].to_i - 1
      pageless_thread_file_name = thread_and_page[0]
    else
      page = 0
      pageless_thread_file_name = thread_file_name
    end
    name_and_id = pageless_thread_file_name.split("%3D")
    if name_and_id.size > 1
      thread_id = name_and_id[-1].to_i
      if !thread_file_hash[thread_id]
        thread_file_hash[thread_id] = []
      end
      thread_file_hash[thread_id][page] = thread_file_name
    end
  end
  puts 'Got threads'
  return [post_file_hash, thread_file_hash]
end

def rename_file(file_name, to_file_name)
  puts "mv #{file_name} #{to_file_name}"
  if file_name
    FileUtils.move(file_name, to_file_name) 
  end
end

args = ARGV.to_a
if args[0] == "user"
  args.delete_at(0)
  initialize_environment(args)
  parse_users()
elsif args[0] == "rename"
  args.delete_at(0)
  initialize_environment(args)
  rename_files()
else
  initialize_environment(args)
  parse_all()
end
