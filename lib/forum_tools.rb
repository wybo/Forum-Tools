require 'rubygems'
require 'net/http'
require 'open-uri'
require 'fileutils'
require 'yaml'

class ForumTools
  CONFIG = {} 

  def self.config(options = {})
    CONFIG.merge!(options)
  end

  class OpenStructArray
    attr_accessor :file_name

    def self.all(class_const, glob_dir_file_name)
      file_names = Dir.glob(glob_dir_file_name)
      list = []
      file_names.each do |file_name|
        list.push(class_const.new(File.basename(file_name)))
      end
      return list
    end

    def initialize(file_name)
      @file_name = file_name
      @spec_attributes = {}
    end

    def to_yaml
      hash = {}
      @spec_attributes.keys.each do |attr|
        hash[attr] = self.send(attr)
      end
      return hash.merge(:items => self.to_a).to_yaml
    end

    def clear
      super.delete_if { true } # using clear for some reason gives stack level too deep
      @spec_attributes.clear()
    end

    def items=(items)
      items.each do |item|
        self << item
      end
    end

  def method_missing(method_id, *arguments)
    if method_id.to_s =~ /^.*=$/
      new_attribute = method_id.to_s.gsub("=","").to_sym
      str = <<-EOS
        attr_reader :#{new_attribute}
        def #{new_attribute}=(value)
          @#{new_attribute} = value
          @spec_attributes[:#{new_attribute}] = 1
        end
      EOS
      self.class.class_eval str
      self.send(method_id, *arguments)
    else
      super(method_id, *arguments)
    end
  end

  end

  class File
    def self.init_dirs
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:raw_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:yaml_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:pajek_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:stat_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:var_dir])
    end

    def self.fetch_html(file_prefix, url)
      file_prefix = File.basename(file_prefix, ".html")
      before = Time.now
      resp = Net::HTTP.get(URI.parse(url))
      after = Time.now
      time = before + ((after - before) / 2.0)
      file_name = CONFIG[:env_dir] + CONFIG[:raw_dir] +
          file_prefix + '_' + time.to_i.to_s + '.html'
      open(file_name, "w") { |file|
        file.write(resp)
      }
      sleep 30 + rand(21)
      return file_name
    end

    def self.save_yaml(file_prefix, structure, options = {})
      open(self.yaml_dir_file_name(file_prefix, options), "w") { |file| 
          file.write(structure.to_yaml) }
    end

    def self.read_yaml(file_prefix, options = {})
      dir_file_name = self.yaml_dir_file_name(file_prefix, options)
      if ::File.exists?(dir_file_name)
        structure = YAML.load(open(dir_file_name))
      else
        structure = {}
      end
      return structure
    end

    def self.delete_yaml(file_prefix, options = {})
      dir_file_name = self.yaml_dir_file_name(file_prefix, options)
      if ::File.exists?(dir_file_name)
        ::File.delete(dir_file_name)
      end
    end

    def self.save_pajek(file_prefix, string)
      file_name = self.set_extension(file_prefix, ".net")
      open(CONFIG[:env_dir] + CONFIG[:pajek_dir] + file_name, "w") { |file|
          file.write(string) }
    end

    def self.save_stat(file_prefix, array)
      file_name = self.set_extension(file_prefix, ".dat")
      if array[0].kind_of?(Array)
        rows = []
        columns = array
        columns.each do |column|
          i = 0
          column.each do |cell|
            if !rows[i]
              rows[i] = []
            end
            rows[i] << cell.to_s
            i += 1
          end
        end
        lines = rows.collect {|row| row.join("\t")}
      else
        lines = array
      end
      open(CONFIG[:env_dir] + CONFIG[:stat_dir] + file_name, "w") { |file|
          file.write(lines.join("\n") + "\n") }
    end

    def self.set_extension(file_prefix, extension)
      return ::File.basename(file_prefix, extension) + extension
    end

    def self.yaml_dir_file_name(file_prefix, options)
      file_name = self.set_extension(file_prefix, ".yaml")
      if options[:var]
        return CONFIG[:env_dir] + CONFIG[:var_dir] + file_name
      else
        return CONFIG[:env_dir] + CONFIG[:yaml_dir] + file_name
      end
    end
  end
end
