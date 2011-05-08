#!/usr/bin/ruby
require 'config'
require 'sioc_parsers'
require 'stores'
require 'time_tools'

puts '### Parsing SIOC (Boards.ie) data'

def parse_threads
  puts '# Parsing threads from xml'
  SIOCThreadParser.all.each do |thread|
    thread.save
  end
  puts '# Parsing posts from xml'
  posts_hash = {}
  SIOCPostParser.all.each do |post|
    posts_hash[post.id] = post
  end
  ThreadStore.all.each do |thread|
    thread.each do |post|
      if posts_hash[post[:id]]
        post.merge!(posts_hash[post[:id]])
      else
        puts "post " + post[:id].to_s + " missing"
      end
    end
    thread.save
  end
end

def parse_all
  parse_threads()
end

args = ARGV.to_a
initialize_environment(args)
parse_all()
