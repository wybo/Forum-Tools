#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'stores'
require 'test/unit'

HNTools.config(:root => "/home/wybo/projects/hnscraper/test/")

class AllTimesStore
  def spec_attributes
    return @spec_attributes
  end
end

class StoresTest < Test::Unit::TestCase
  def test_read_thread
    thread = ThreadStore.new('thread_2158111.yaml')
    assert_equal 2158111, thread[0][:id]
    assert thread[0][:id].kind_of?(Integer)
    assert_equal "nika", thread[0][:user]
    assert_equal 24, thread.size
  end

  def test_save_thread
    thread_orig = ThreadStore.new('thread_2158111.yaml')
    thread = ThreadStore.new('thread_2158111.yaml')
    thread[0][:time] = 1296459999
    thread.hakuna = 433
    thread.save
    thread2 = ThreadStore.new('thread_2158111.yaml')
    assert_equal 1296459999, thread2[0][:time]
    assert_equal 433, thread2.hakuna
    assert_equal 24, thread2.size
    assert_equal nil, thread_orig.hakuna
    thread_orig.save
    all = AllTimesStore.new
    assert !all.respond_to?(:hakuna)
    assert all.spec_attributes().empty?
  end
end
