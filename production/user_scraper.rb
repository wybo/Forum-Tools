#!/usr/bin/ruby
File.expand_path(File.dirname(__FILE__) + "../")
require 'config.rb'
require 'stores'
require 'hn_parsers'

initialize_environment(ARGV)

def fetch_user_pages
  puts "### Fetching user pages"
  users = []
  puts "# Reading user-names"
  ThreadStore.all.each do |thread|
    thread.each do |post|
      raise "Invalid name: " + post[:user] if post[:user] !~ /^[\w_-]+$/
      users << post[:user]
    end
  end
  users.uniq!
  puts "# Checking for pages already fetched"
  HNUserParser.all.each do |user|
    users.delete(user.name)
  end
  puts "# Fetching #{users.size.to_s} pages"
  i = 0
  users.each do |user|
    print "."
    if ForumTools::CONFIG[:environment] != "test" or user == "digitalclubb"
      ForumTools::File.fetch_html("user_grun_" + user, "http://news.ycombinator.com/user?id=" + user)
    end
    if i % 100 == 0
      print i.to_s
    end
    i += 1
  end
  print "\n"
end

fetch_user_pages()
