require 'rubygems'
require 'fileutils'

class HNTools
  CONFIG = {} 
  CONFIG[:raw_dir] = "raw/"
  CONFIG[:yaml_dir] = "yaml/"
  CONFIG[:pajek_dir] = "pajek/"
  CONFIG[:stat_dir] = "stat/"
  CONFIG[:root_dir] = "" # set before use

  def self.config(options = {})
    CONFIG.merge!(options)
    if options[:root_dir]
      self.init_dirs 
    end
  end

  def self.init_dirs
    FileUtils.mkdir_p(HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:raw_dir])
    FileUtils.mkdir_p(HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:yaml_dir])
    FileUtils.mkdir_p(HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:pajek_dir])
    FileUtils.mkdir_p(HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:stat_dir])
  end

  class File
    def self.save_yaml(file_name, structure)
      open(CONFIG[:root_dir] + CONFIG[:yaml_dir] + file_name, "w") { |file| file.write(structure.to_yaml) }
    end

    def self.read_yaml(file_name)
      if ::File.exists?(CONFIG[:root_dir] + CONFIG[:yaml_dir] + file_name)
        structure = YAML.load(open(CONFIG[:root_dir] + CONFIG[:yaml_dir] + file_name))
      else
        structure = {}
      end
      return structure
    end

    def self.delete_yaml(file_name)
      if ::File.exists?(CONFIG[:root_dir] + CONFIG[:yaml_dir] + file_name)
        ::File.delete(CONFIG[:root_dir] + CONFIG[:yaml_dir] + file_name)
      end
    end

    def self.save_pajek(file_name, string)
      open(CONFIG[:root_dir] + CONFIG[:pajek_dir] + file_name, "w") { |file| file.write(string) }
    end

    def self.save_stat(file_name, array)
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
      open(CONFIG[:root_dir] + CONFIG[:stat_dir] + file_name, "w") { |file| file.write(lines.join("\n")) }
    end
  end
end
