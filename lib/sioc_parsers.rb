require 'forum_tools'
require 'active_support/all'
require 'nokogiri'
require 'chronic'
require 'yaml'
require 'open_struct_array'

class SIOCParser < OpenStructArray
  @@errors = []

  def self.all(class_const, file_regexp, &block)
    super(class_const, ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir], file_regexp, &block)
  end

  def self.all_file_names(file_regexp)
    super(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir], file_regexp)
  end

  def self.errors
    return @@errors
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
  def self.all(&block)
    return SIOCParser.all(SIOCThreadParser, "**/threads/**/*", &block)
  end

  def self.all_file_names
    return SIOCParser.all_file_names("**/threads/**/*")
  end

  # Parses details and all posts if given an array of file-names, and
  # posts for later pages only, if given a string
  def initialize(file_names)
    begin
      if file_names.kind_of?(String)
        super(file_names)
        doc = self.read_xml()
        self.parse_posts(doc, false)
      else
        super(file_names[0])
        doc = self.read_xml()
        self.id = doc.at_xpath('//sioc:Thread/sioc:link/@rdf:resource').to_s.split('=')[-1].to_i
        self.title = doc.at_xpath('//sioc:Thread/dc:title/text()').to_s
        time_string = doc.at_xpath('//sioc:Thread/dcterms:created/text()').to_s
        self.on_frontpage_time = Time.parse(time_string, Time.now.utc).to_i
        self.forum_id = doc.at_xpath('//sioc:Thread//sioc:Forum/@rdf:about').to_s.split('=')[-1].to_i
        self.parse_posts(doc, true)
        if file_names.size > 1
          file_names[1..-1].each do |file_name|
            thread = SIOCThreadParser.new(file_name)
            thread.each do |post|
              self << post
            end
          end
        end
      end
    rescue
      puts file_name
      @@errors << file_name
    end
    return self
  end

  def parse_posts(doc, first_page)
    first = first_page
    posts = doc.xpath('//sioc:Thread//sioc:Post/@rdf:about')
    posts.each do |post|
      self << {:id => post.to_s.split('=')[-1].to_i, :indent => (first ? 0 : 1)}
      first = false
    end
  end

  def save
    y_file_name = self.forum_id.to_s + "/thread_" + self.id.to_s + ".yaml"
    ForumTools::File.save_yaml(y_file_name, self)
  end
end

class SIOCPostParser < SIOCParser
  def self.all
    return SIOCParser.all(SIOCPostParser, "**/posts/**/*")
  end

  def self.all_file_names
    return SIOCParser.all_file_names("**/posts/**/*")
  end

  def initialize(file_name)
    super(file_name)
    begin
      doc = self.read_xml()
      self.id = doc.at_xpath('//sioct:BoardPost/@rdf:about').to_s.split('=')[-1].to_i
      time_string = doc.at_xpath('//sioct:BoardPost/dcterms:created/text()').to_s
      self.time = Time.parse(time_string, Time.now.utc).to_i
      user_string = doc.at_xpath('//sioct:BoardPost//sioc:User/@rdf:about').to_s.split('=')[-1]
      if user_string
        self.user = user_string.split("#")[0].to_i
      end
      reply_ofs = doc.xpath('//sioct:BoardPost/sioc:reply_of/sioc:Post/@rdf:about')
      if !reply_ofs.empty?
        reply_of_ids = []
        reply_ofs.each do |reply_of|
          reply_of_ids << reply_of.to_s.split('=')[-1].to_i
        end
        self.replies_to = reply_of_ids
      end
    rescue
      @@errors << file_name
      puts file_name
    end
    return self
  end
end
