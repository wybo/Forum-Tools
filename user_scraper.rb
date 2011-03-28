#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/lib")
require 'rubygems'
require 'net/http'
require 'open-uri'
require 'stores'
require 'parsers'

DATA_STORE = "data/raw/"
SLEEP = true

HNTools.config(:root_dir => "/home/wybo/projects/hnscraper/data/")

def fetch_user_pages
  users = []
  ThreadStore.all.each do |thread|
    thread.each do |post|
      raise "Invalid name: " + post[:user] if post[:user] !~ /^[\w_-]+$/
      users << post[:user]
    end
  end
  users.uniq!
  HNUserParser.all.each do |user|
    users.delete(user.user)
  end
  users.each do |user|
    if user == "yarapavan"
      fetch("http://news.ycombinator.com/user?id=" + user, "user_grun_" + user)
    end
  end
end

### Helper functions

def fetch(url, file_prefix)
  before = Time.now
  resp = Net::HTTP.get(URI.parse(url))
  after = Time.now
  time = before + ((after - before) / 2.0)
  file_name = DATA_STORE + file_prefix + '_' + time.to_i.to_s + '.html'
  open(file_name, "w") { |file|
    file.write(resp)
  }
  sleep 30 + rand(21) if SLEEP
  return file_name
end

fetch_user_pages()
