#!/usr/bin/ruby
require 'config'
require 'stores'

puts '### Anonymizing data'

def anonymize(options = {})
  puts '# Anonymizing user store'
  users = UsersStore.new()
  users.shuffle!
  code_hash = {}
  name = "aaaa"
  users.each do |user|
    code_hash[user[:name]] = name
    user[:name] = code_hash[user[:name]]
    name = name.next
  end
  users.save
  users = nil
  puts '# Anonymizing threads'
  threads = ThreadStore.all()
  threads.each do |thread|
    thread.each do |post|
      post[:user] = code_hash[post[:user]]
    end
    thread.save
  end
  puts '# done'
end

args = ARGV.to_a
initialize_environment(args)
anonymize()
