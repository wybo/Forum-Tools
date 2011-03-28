require 'rubygems'
require 'yaml'
require 'h_n_tools'

HNTools::CONFIG[:all_times_file_name] = "all_times.yaml"
HNTools::CONFIG[:times_file_name] = "times.yaml"

class Store < Array
  attr_accessor :file_name

  def self.all(class_const, file_regexp)
    file_names = Dir.glob(HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:yaml_dir] + file_regexp)
    list = []
    file_names.each do |file_name|
      list.push(class_const.new(File.basename(file_name)))
    end
    return list
  end

  def initialize(file_name)
    @file_name = file_name
    @spec_attributes = {}
    self.from_hash(HNTools::File.read_yaml(@file_name))
    return self
  end

  def from_hash(structure)
    structure.each_pair do |key, value|
      self.send(key.to_s + '=', value)
    end
  end

  def to_yaml
    hash = {}
    @spec_attributes.keys.each do |attr|
      hash[attr] = self.send(attr)
    end
    return hash.merge(:items => self.to_a).to_yaml
  end

  def save
    HNTools::File.save_yaml(@file_name, self)
  end

  def delete
    HNTools::File.delete_yaml(@file_name)
  end

  def items=(items)
    items.each do |item|
      self << item
    end
  end

  def clear
    super.delete_if { true } # using clear for some reason gives stack level too deep
    @spec_attributes.clear()
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

class ThreadStore < Store
  def self.all
    return Store.all(ThreadStore, "thread*")
  end

  def initialize(options = {})
    if options.kind_of?(String)
      super(options)
    elsif options.kind_of?(Integer)
      super("thread_" + options.to_s + ".yaml")
    else
      raise 'Invalid options: ' + options.inspect
    end
  end
end

class AllTimesStore < Store
  def initialize()
    super(HNTools::CONFIG[:all_times_file_name])
  end

  def add_times(items)
    items.each do |item|
      if item[:time_string] =~ /minute/
        self << {:id => item[:id], :time => item[:time]}
      end
    end
  end

  def to_canonical_times
    hash = {}
    self.each do |item|
      if !hash[item[:id]]
        hash[item[:id]] = []
      end
      hash[item[:id]].push(item[:time])
    end
    array = []
    hash.each_pair do |key, times|
      canonical_time = 0
      if times.size > 1
        adder = 0
        times.each do |time|
          adder += time
        end
        canonical_time = adder / times.size
      else
        canonical_time = times[0]
      end
      array.push({:id => key, :time => canonical_time})
    end
    array.sort! {|x,y| x[:id] <=> y[:id] }
    return TimesStore.new(:array => array)
  end
end

class TimesStore < Store
  def initialize(options = {})
    super(HNTools::CONFIG[:times_file_name])
    if options[:array]
      clear()
      options[:array].each do |item|
        self << item
      end
    end
  end

  def time(id)
    i_before = find_before_index(id, 0, self.size - 1)
    if id < self[i_before][:id] or id > self[i_before + 1][:id]
      # out of range 
      # (smaller than first for which data, or larger than last)
      return nil
    end
    id_before = self[i_before][:id]
    id_after = self[i_before + 1][:id]
    time_before = self[i_before][:time]
    time_after = self[i_before + 1][:time]

    id_gap = id_after - id_before
    #    gap = B <------------------> A
    id_offset = id - id_before
    # offset = B <--------------> Id
    fraction = (id_offset * 1.0) / id_gap
    #  fract = offset / gap = 0.8
    time_gap = time_after - time_before
    time = time_before + (time_gap * fraction).to_i
    return time
  end

  def find_before_index(id, i_start, i_end)
    if i_end - i_start < 2
      return i_start
    end
    middle = (i_start + i_end) / 2
    if self[middle][:id] < id
      find_before_index(id, middle, i_end)
    else
      find_before_index(id, i_start, middle)
    end
  end
end

class UserStore < Store
  def self.all
    return Store.all(ThreadStore, "user*")
  end

  def initialize(options = {})
    if options.kind_of?(String)
      if options =~ /\.yaml$/
        super(options)
      else
        super("user_" + options + ".yaml")
      end
    else
      raise 'Invalid options: ' + options.inspect
    end
  end
end

