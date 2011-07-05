#!/usr/bin/ruby
File.expand_path(File.dirname(__FILE__) + "../")
require 'config.rb'
require 'stores'
require 'hn_parsers'

initialize_environment(ARGV)

def fetch_timezone_pages
  puts "### Fetching timezone pages"
  pages = [
      {:name => "uk",
       :url => "http://www.hackernewsers.com/users.html?User[countryId]=826&User_page=",
       :range => 19},
      {:name => "westcoast",
       :url => "http://www.hackernewsers.com/users.html?User[countryId]=840&User_page=",
       :range => 97}]
       # :url => "http://www.hackernewsers.com/users.html?User[countryId]=840&User[timezone]=America%2FLos_Angeles",
       # :url => "http://www.hackernewsers.com/users.html?User[countryId]=826&User[timezone]=Europe%2FLondon",
  pages.each do |page|
    page[:range].times do |i|
      if i > 0
        ForumTools::File.fetch_html("country_" + page[:name] + "_" + i.to_s, page[:url] + i.to_s)
      end
      print "."
    end
  end
  print "\n"
end

fetch_timezone_pages()
