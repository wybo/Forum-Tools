#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'parsers'
require 'test/unit'

HNTools.config(:root => "/home/wybo/projects/hnscraper/test/")

class ParsersTest < Test::Unit::TestCase
  def test_thread
    thread = HNThreadParser.new('thread_final_2158111_1296537573.html')
    assert_equal 2158111, thread[0][:id]
    assert thread[0][:id].kind_of?(Integer)
    assert_equal 1296451173, thread[0][:time]
    assert thread[0][:time].kind_of?(Integer)
    assert_equal 24, thread.size
  end

  def test_comments
    comments = HNCommentsParser.new('newcomments_1296594423.html')
    assert_equal 2167400, comments[0][:id] 
    assert_equal 1296594423, comments[0][:time]
    assert_equal 1296594303, comments[4][:time]
    assert_equal 30, comments.size
  end

  def test_index
    index = HNIndexParser.new('index_1296436622.html')
    assert_equal 2159719, index[0][:id]
    assert_equal 30, index.size
  end

  def test_newest
    index = HNIndexParser.new('newest_1296436657.html')
    assert_equal 2159829, index[0][:id]
    assert_equal 30, index.size
  end
end
