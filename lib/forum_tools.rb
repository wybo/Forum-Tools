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

  class File
    def self.clear_dirs
      if CONFIG[:env_dir] == CONFIG[:production_dir]
        raise "Cannot clear dir as this would delete all files"
      end
      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:data_dir])
      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:var_dir])
    end

    def self.init_dirs
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:raw_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:yaml_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:pajek_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:stat_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:var_dir])
    end

    def self.fetch_html(file_prefix, url)
      file_prefix = ::File.basename(file_prefix, ".html")
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
      structure = false
      if ::File.exists?(dir_file_name)
        structure = YAML.load(open(dir_file_name))
      end
      if !structure # YAML returns false if no valid / empty file
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

    def self.save_pajek(file_prefix, network_hash, options = {})
      if options[:undirected]
        edges = "Edges"
      else
        edges = "Arcs"
      end

      keys = []
      network_hash.each_pair do |key1, hash|
        keys << key1
        hash.keys.each do |key2|
          keys << key2
        end
      end
      keys.sort!
      keys.uniq!

      keys_hash = {}
      i = 1
      keys.each do |key|
        keys_hash[key] = i
        i += 1
      end

      lines = ["*Vertices #{keys.size.to_s}"]
      keys.each do |key|
        lines << "#{keys_hash[key].to_s} \"#{key}\""
      end
      lines << "*#{edges}"
      network_hash.keys.sort.each do |key1|
        network_hash[key1].each_pair do |key2, weight|
          lines << "#{keys_hash[key1].to_s} #{keys_hash[key2].to_s} #{weight.to_s}"
        end
      end
      file_name = self.set_extension(file_prefix, ".net")
      open(CONFIG[:env_dir] + CONFIG[:pajek_dir] + file_name, "w") { |file|
          file.write(lines.join("\n") + "\n") }
    end

    def self.parse_file_time(file_name)
      return file_name.split('_')[-1].split('.')[0].to_i
    end

    ### Helpers

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
