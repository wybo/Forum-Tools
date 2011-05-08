require 'forum_tools'
require 'active_support/all'
require 'nokogiri'
require 'chronic'
require 'yaml'
require 'open_struct_array'

class SIOCParser < OpenStructArray
  def self.all(class_const, file_regexp, options = {})
#    raw_dir = "/home/wybo/space/corpora/boards/unpacked/"
    raw_dir = ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir]
    super(class_const, raw_dir, file_regexp)
  end

  def initialize(file_name)
    file_name = file_name.gsub(
        ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir], "")
    super(file_name)
    return self
  end

  def read_xml
    return Nokogiri::XML(open(
        ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir] + @file_name))
  end
end

class SIOCThreadParser < SIOCParser
  @@last = nil

  def self.all
    return SIOCParser.all(SIOCThreadParser, "**/threads/**/*")
  end

  def initialize(file_name)
    super(file_name)
    doc = self.read_xml()
    self.id = doc.at_xpath('//sioc:Thread/sioc:link/@rdf:resource').to_s.split('=')[-1].to_i
    self.title = doc.at_xpath('//sioc:Thread/dc:title/text()').to_s
    time_string = doc.at_xpath('//sioc:Thread/dcterms:created/text()').to_s
    self.on_frontpage_time = Time.parse(time_string, Time.now.utc).to_i
    self.forum_id = doc.at_xpath('//sioc:Thread//sioc:Forum/@rdf:about').to_s.split('=')[-1].to_i
    posts = doc.xpath('//sioc:Thread//sioc:Post/@rdf:about')
    if self.file_name =~ /page/
      first = false
      @@last.each do |post|
        self << post
      end
    else
      first = true
    end
    posts.each do |post|
      self << {:id => post.to_s.split('=')[-1].to_i, :indent => (first ? 0 : 1)}
      first = false
    end
    @@last = self
    return self
  end

  def save
    y_file_name = self.forum_id.to_s + "/thread_" + self.on_frontpage_time.to_s + "_" +
        self.id.to_s + ".yaml"
    ForumTools::File.save_yaml(y_file_name, self)
  end
end

class SIOCPostParser < SIOCParser
  def self.all
    return SIOCParser.all(SIOCPostParser, "**/posts/**/*")
  end

  def initialize(file_name)
    super(file_name)
    doc = self.read_xml()
    self.id = doc.at_xpath('//sioct:BoardPost/@rdf:about').to_s.split('=')[-1].to_i
    time_string = doc.at_xpath('//sioct:BoardPost/dcterms:created/text()').to_s
    self.time = Time.parse(time_string, Time.now.utc).to_i
    user_string = doc.at_xpath('//sioct:BoardPost//sioc:User/@rdf:about').to_s.split('=')[-1]
    if user_string
      self.user = user_string.split("#")[0].to_i
    end
    return self
  end
end
