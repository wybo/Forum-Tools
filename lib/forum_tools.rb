require 'rubygems'
require 'net/http'
require 'open-uri'
require 'fileutils'
require 'yaml'
require 'json'

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
      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:var_dir])
      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:data_dir])
#      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:raw_dir])
#      FileUtils.rm_rf(CONFIG[:env_dir] + CONFIG[:yaml_dir])

    end

    def self.init_dirs
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:var_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:raw_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:yaml_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:net_dir])
      FileUtils.mkdir_p(CONFIG[:env_dir] + CONFIG[:stat_dir])
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

    def self.save_json(file_prefix, structure, options = {})
      if options[:variable]
        variable = options[:variable]
      else
        variable = "thread"
      end
      json_str = "var #{variable} = eval('(" + structure.to_json + ")');"
      open(self.json_dir_file_name(file_prefix, options), "w") { |file| 
          file.write(json_str) }
    end

    def self.save_stat(file_prefix, array, options = {})
      file_name = self.set_extension(file_prefix, ".raw")
      if options[:add_case_numbers]
        if array[0].kind_of?(Array)
          array.insert(0,["case"].concat((array[0].size - 1).times.to_a))
        else
          array = [["case"].concat((array.size - 1).times.to_a), array]
        end
      end
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

    def self.parse_file_time(file_name)
      return file_name.split('_')[-1].split('.')[0].to_i
    end

    def self.save_networks(file_prefix, network_hash, options = {})
      self.save_pajek(file_prefix, network_hash, options)
      self.save_gexf(file_prefix, network_hash, options)
      self.save_graphml(file_prefix, network_hash, options)
      NetworkStore.new(file_prefix, :hash => network_hash).save
    end

    def self.save_pajek(file_prefix, network_hash, options = {})
      if options[:undirected]
        edges = "Edges"
      else
        edges = "Arcs"
      end

      users = ::ForumTools::Data.get_unique_users(network_hash)
      users_hash = ::ForumTools::Data.get_users_hash(users)

      lines = ["*Vertices #{users.size.to_s}"]
      colors = ""
      users.each do |user|
        if options[:coordinates]
          coordinates_arr = options[:coordinates][:pajek][user]
          coordinates = "#{sprintf("%.4f", coordinates_arr[0])} #{sprintf("%.4f", coordinates_arr[1])} 0.0000"
        else
          coordinates = "0.0000 0.0000 0.0000"
        end
        if options[:colors]
          colors = " " + coordinates + " " + options[:colors][:pajek][user].join(" ")
        end
        lines << "#{users_hash[user].to_s} \"#{user}\"#{colors}"
      end
      lines << "*#{edges}"
      network_hash.keys.sort.each do |user1|
        network_hash[user1].keys.sort.each do |user2|
          weight = network_hash[user1][user2]
          lines << "#{users_hash[user1].to_s} #{users_hash[user2].to_s} #{weight.to_s}"
        end
      end
      file_name = self.set_extension(file_prefix, ".net")
      open(CONFIG[:env_dir] + CONFIG[:net_dir] + file_name, "w") { |file|
          file.write(lines.join("\n") + "\n") }
    end

    def self.save_gexf(file_prefix, network_hash, options = {})
      chunks = []
      chunks << <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<gexf xmlns="http://www.gexf.net/1.1draft" version="1.1" xmlns:viz="http://www.gexf.net/1.1draft/viz" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.1draft/gexf.xsd">
  <meta lastmodifieddate="#{Time.now.strftime("%Y-%m-%d")}">
    <creator>ForumTools</creator>
    <description></description>
  </meta>
  <graph mode="static" defaultedgetype="#{(options[:undirected] ? "undirected" : "directed")}" timeformat="double">
    <nodes>
EOS
      users = ::ForumTools::Data.get_unique_users(network_hash)
      users_hash = ::ForumTools::Data.get_users_hash(users)
      users.each do |user|
        chunks << <<-EOS
      <node id="#{users_hash[user]}" label="#{user}">
        <attvalues></attvalues>
EOS
        if options[:colors]
          colors = options[:colors][:gexf][user]
          chunks << <<-EOS
        <viz:color r="#{colors[0]}" g="#{colors[1]}" b="#{colors[2]}" a="0.8"></viz:color>
EOS
        end
        if options[:coordinates]
          coordinates = options[:coordinates][:gexf][user]
          chunks << <<-EOS
        <viz:position x="#{sprintf("%.4f", coordinates[0])}" y="#{sprintf("%.4f", coordinates[1])}"></viz:position>
EOS
        end
        chunks << <<-EOS
      </node>
EOS
      end
      chunks << <<-EOS
    </nodes>
    <edges>
EOS
      i = 0
      network_hash.keys.sort.each do |user1|
        network_hash[user1].keys.sort.each do |user2|
          weight = network_hash[user1][user2]
            chunks << <<-EOS
      <edge id="#{i.to_s}" source="#{users_hash[user1]}" target="#{users_hash[user2]}" weight="#{weight}">
        <attvalues></attvalues>
EOS
        if options[:edge_colors]
          colors = options[:edge_colors][:gexf][user1][user2]
          chunks << <<-EOS
        <viz:color r="#{colors[0]}" g="#{colors[1]}" b="#{colors[2]}" a="0.8"></viz:color>
EOS
        end
      chunks << <<-EOS
      </edge>
EOS
          i += 1
        end
      end
      chunks << <<-EOS
    </edges>
  </graph>
</gexf>
EOS
      file_name = self.set_extension(file_prefix, ".gexf")
      open(CONFIG[:env_dir] + CONFIG[:net_dir] + file_name, "w") { |file|
          file.write(chunks.join()) }
    end

    def self.save_graphml(file_prefix, network_hash, options = {})
      chunks = []
      chunks << <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <key id="V-Degree" for="node" attr.name="Degree" attr.type="string" />
  <key id="V-In-Degree" for="node" attr.name="In-Degree" attr.type="string" />
  <key id="V-Out-Degree" for="node" attr.name="Out-Degree" attr.type="string" />
  <key id="V-Betweenness Centrality" for="node" attr.name="Betweenness Centrality" attr.type="string" />
  <key id="V-Closeness Centrality" for="node" attr.name="Closeness Centrality" attr.type="string" />
  <key id="V-Eigenvector Centrality" for="node" attr.name="Eigenvector Centrality" attr.type="string" />
  <key id="V-PageRank" for="node" attr.name="PageRank" attr.type="string" />
  <key id="V-Clustering Coefficient" for="node" attr.name="Clustering Coefficient" attr.type="string" />
  <key id="V-Color" for="node" attr.name="Color" attr.type="string" />
  <key id="V-Shape" for="node" attr.name="Shape" attr.type="string" />
  <key id="V-Size" for="node" attr.name="Size" attr.type="string" />
  <key id="V-Opacity" for="node" attr.name="Opacity" attr.type="string" />
  <key id="V-Image File" for="node" attr.name="Image File" attr.type="string" />
  <key id="V-Visibility" for="node" attr.name="Visibility" attr.type="string" />
  <key id="V-Label" for="node" attr.name="Label" attr.type="string" />
  <key id="V-Label Fill Color" for="node" attr.name="Label Fill Color" attr.type="string" />
  <key id="V-Label Position" for="node" attr.name="Label Position" attr.type="string" />
  <key id="V-Tooltip" for="node" attr.name="Tooltip" attr.type="string" />
  <key id="V-Layout Order" for="node" attr.name="Layout Order" attr.type="string" />
  <key id="V-X" for="node" attr.name="X" attr.type="string" />
  <key id="V-Y" for="node" attr.name="Y" attr.type="string" />
  <key id="V-Locked?" for="node" attr.name="Locked?" attr.type="string" />
  <key id="V-Polar R" for="node" attr.name="Polar R" attr.type="string" />
  <key id="V-Polar Angle" for="node" attr.name="Polar Angle" attr.type="string" />
  <key id="V-ID" for="node" attr.name="ID" attr.type="string" />
  <key id="V-Dynamic Filter" for="node" attr.name="Dynamic Filter" attr.type="string" />
  <key id="V-Add Your Own Columns Here" for="node" attr.name="Add Your Own Columns Here" attr.type="string" />
  <key id="E-Color" for="edge" attr.name="Color" attr.type="string" />
  <key id="E-Width" for="edge" attr.name="Width" attr.type="string" />
  <key id="E-Style" for="edge" attr.name="Style" attr.type="string" />
  <key id="E-Opacity" for="edge" attr.name="Opacity" attr.type="string" />
  <key id="E-Visibility" for="edge" attr.name="Visibility" attr.type="string" />
  <key id="E-Label" for="edge" attr.name="Label" attr.type="string" />
  <key id="E-Label Text Color" for="edge" attr.name="Label Text Color" attr.type="string" />
  <key id="E-Label Font Size" for="edge" attr.name="Label Font Size" attr.type="string" />
  <key id="E-ID" for="edge" attr.name="ID" attr.type="string" />
  <key id="E-Dynamic Filter" for="edge" attr.name="Dynamic Filter" attr.type="string" />
  <key id="E-Add Your Own Columns Here" for="edge" attr.name="Add Your Own Columns Here" attr.type="string" />
  <key id="E-Edge Weight" for="edge" attr.name="Edge Weight" attr.type="string" />
  <graph edgedefault="#{(options[:undirected] ? "undirected" : "directed")}">
EOS
      users = ::ForumTools::Data.get_unique_users(network_hash)
      users_hash = ::ForumTools::Data.get_users_hash(users)
      users.each do |user|
        chunks << <<-EOS
    <node id="#{users_hash[user]}">
      <data key="V-ID">#{users_hash[user]}</data>
      <data key="V-Label">#{user}</data>
EOS
        if options[:colors]
          colors = options[:colors][:gexf][user]
          chunks << <<-EOS
      <data key="V-Color">#{colors[0]}; #{colors[1]}; #{colors[2]}</data>
EOS
        end
        if options[:coordinates]
          coordinates = options[:coordinates][:graphml][user]
          chunks << <<-EOS
      <data key="V-X">#{sprintf("%.1f", coordinates[0])}</data>
      <data key="V-Y">#{sprintf("%.1f", coordinates[1])}</data>
EOS
        end
        chunks << <<-EOS
    </node>
EOS
      end

      i = 0
      network_hash.keys.sort.each do |user1|
        network_hash[user1].keys.sort.each do |user2|
          weight = network_hash[user1][user2]
            chunks << <<-EOS
      <edge source="#{users_hash[user1]}" target="#{users_hash[user2]}">
        <data key="E-ID">#{i}</data>
EOS
            if options[:edge_colors]
              colors = options[:edge_colors][:gexf][user1][user2]
              chunks << <<-EOS
        <data key="E-Color">#{colors[0]}; #{colors[1]}; #{colors[2]}</data>
EOS
        end
            chunks << <<-EOS
        <data key="E-Width">#{weight}</data>
        <data key="E-Opacity">40</data>
      </edge>
EOS
        #<data key="E-Edge Weight">#{weight.to_s}</data>
          i += 1
        end
      end
      chunks << <<-EOS
  </graph>
</graphml>
EOS
      file_name = self.set_extension(file_prefix, ".graphml")
      open(CONFIG[:env_dir] + CONFIG[:net_dir] + file_name, "w") { |file|
          file.write(chunks.join()) }
    end

    ### Helpers

    def self.set_extension(file_prefix, extension)
      return ::File.basename(file_prefix, extension) + extension
    end

    def self.json_dir_file_name(file_prefix, options)
      file_name = self.set_extension(file_prefix, ".json.js")
      return CONFIG[:abf_dir] + file_name
    end

    def self.yaml_dir_file_name(file_prefix, options)
      file_name = self.set_extension(file_prefix, ".yaml")
      if options[:env_dir]
        env_dir = options[:env_dir]
      else
        env_dir = CONFIG[:env_dir]
      end
      if options[:var]
        return env_dir + CONFIG[:var_dir] + file_name
      else
        return env_dir + CONFIG[:yaml_dir] + file_name
      end
    end
  end

  class Data
    def self.get_unique_users(network_hash)
      users = []
      network_hash.each_pair do |user1, hash|
        users << user1
        hash.keys.each do |user2|
          users << user2
        end
      end
      users.sort!
      return users.uniq
    end

    def self.get_users_hash(users)
      users_hash = {}
      i = 1
      users.each do |user|
        users_hash[user] = i
        i += 1
      end
      return users_hash
    end

    def self.sample(array_or_hash, size)
      if array_or_hash.kind_of?(Hash)
        sampled_keys = self.sample(array_or_hash.keys, size)
        new_hash = {}
        sampled_keys.each do |key|
          new_hash[key] = array_or_hash[key]
        end
        return new_hash
      end
      if array_or_hash.size <= size
        return array_or_hash
      end
      sample = []
      included_hash = {}
      while sample.size < size
        pick = array_or_hash.choice
        if !included_hash[pick]
          sample << pick
          included_hash[pick] = 1
        end
      end
      return sample
    end
  end
end
