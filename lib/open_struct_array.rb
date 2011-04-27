require 'json'

class OpenStructArray < Array
  def self.all(class_const, glob_dir_file_name)
    file_names = Dir.glob(glob_dir_file_name)
    list = []
    file_names.each do |file_name|
      print "."
      instance = class_const.new(File.basename(file_name))
      if instance
        list.push(instance)
      end
    end
    print "\n"
    return list
  end

  def initialize(file_name)
    @spec_attributes = {}
    self.file_name = file_name
  end

  def to_hash
    hash = {}
    @spec_attributes.keys.each do |attr|
      if attr != :file_name
        hash[attr] = self.send(attr)
      end
    end
    if !self.empty?
      hash.merge!(:items => self.to_a)
    end
    return hash
  end

  def to_yaml
    self.to_hash.to_yaml
  end

  def to_json
    self.to_hash.to_json
  end

  def clear_array
    self.delete_if { true } # as alternative to clear
  end

  def clear
    self.clear_array()
    @spec_attributes.clear()
  end

  def items=(items)
    self.clear_array
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
