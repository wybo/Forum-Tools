#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/lib")
require 'parsers'
require 'stores'

HNTools.config(:root_dir => "/home/wybo/projects/hnscraper/data/")

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
  puts '# Estimating time threads appeared on frontpage'
  puts 'reading index pages:'
  indices = HNIndexParser.all("index*")
  indices.sort {|x, y| x.save_time <=> y.save_time}
  puts 'estimating:'
  done_hash = {}
  indices.each do |index|
    print "."
    index.each do |thread|
      if !done_hash[thread[:id]]
        full_thread = ThreadStore.new(thread[:id])
        full_thread.on_frontpage_time = index.save_time
        full_thread.save
        done_hash[thread[:id]] = 1
      end
    end
  end
  print "\n"
end

def prune
  puts '# Removing incomplete data'
  ThreadStore.all.each do |thread|
    print "."
    delete = false
    if !thread.respond_to?(:on_frontpage_time) or !thread.on_frontpage_time
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
    if delete
      puts "\ndeleting " + thread.file_name
      thread.delete
    end
  end
  print "\n"
end

def parse_users
  puts '# Parsing users from html'
  HNUserParser.all.each do |user|
    user.save
  end
end

def parse_all
  parse_threads()
  parse_all_times()
  calculate_canonical_times()
  update_thread_post_times()
  set_on_frontpage_times()
  prune()
end

parse_all()
#parse_users()
