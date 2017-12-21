require 'forwardable'

Module.module_eval do
  # Adds ability to forward methods to other objects using 'def_delegator'
  include Forwardable
end

module Rfm
  module Refinements
    refine Hash do
    	# Extract key-value pairs from self, given list of objects.
    	# Pulled from SplashRails project.
    	# If last object given is hash, it will be the collector for the extracted pairs.
    	# Extracted pairs are deleted from the original hash (self).
    	# Returns the extracted pairs as a hash or as the supplied collector hash.
    	# Attempts to ignore case.
    	def extract(*keys, **recipient)
    		#other_hash = args.last.is_a?(Hash) ? args.pop : {}
    		recipient = recipient.empty? ? Hash.new : recipient
    		recipient.tap do |other|
    			self.delete_if {|k,v| (keys.include?(k) || keys.include?(k.to_s) || keys.include?(k.to_s.downcase) || keys.include?(k.to_sym)) || keys.include?(k.to_s.downcase.to_sym) ? recipient[k]=v : nil}
    		end
    	end  
    end
  end
end # 

return 0


class Object

  #extend Forwardable

  # Adds methods to put instance variables in rfm_metaclass, plus getter/setters
  # This is useful to hide instance variables in objects that would otherwise show "too much" information.
  def self.meta_attr_accessor(*names)
    meta_attr_reader(*names)
    meta_attr_writer(*names)
  end

  def self.meta_attr_reader(*names)
    names.each do |n|
      define_method(n.to_s) {rfm_metaclass.instance_variable_get("@#{n}")}
    end
  end

  def self.meta_attr_writer(*names)
    names.each do |n|
      define_method(n.to_s + "=") {|val| rfm_metaclass.instance_variable_set("@#{n}", val)}
    end
  end

  # Wrap an object in Array, if not already an Array,
  # since XmlMini doesn't know which will be returnd for any particular element.
  # See Rfm Layout & Record where this is used.
  def rfm_force_array
    return [] if self.nil?
    self.is_a?(Array) ? self : [self]
  end

  # Just testing this functionality
  def rfm_local_methods
    self.methods - self.class.superclass.methods
  end

  private

  # Like singleton_method or 'metaclass' from ActiveSupport.
  def rfm_metaclass
    class << self
      self
    end
  end

  # Get the superclass object of self.
  def rfm_super
    SuperProxy.new(self)
  end

end # Object


class Array
  # Taken from ActiveSupport extract_options!.
  def rfm_extract_options!
    last.is_a?(::Hash) ? pop : {}
  end

  # These methods allow dynamic extension of array members with other modules.
  # These methods also carry the @root object for reference, when you don't have the
  # root object explicity referenced anywhere.
  #
  # These methods might slow down array traversal, as
  # they add interpreted code to methods that were otherwise pure C.
  def rfm_extend_members(klass, caller=nil)
    @parent = caller
    @root = caller.instance_variable_get(:@root)
    @member_extension = klass
    self.instance_eval do
      class << self
        attr_accessor :parent

        alias_method 'old_reader', '[]'
        def [](*args)
          member = old_reader(*args)
          rfm_extend_member(member, @member_extension, args[0]) if args[0].is_a? Integer
          member
        end

        alias_method 'old_each', 'each'
        def each
          i = -1
          old_each do |member|
            i = i + 1
            rfm_extend_member(member, @member_extension, i)
            yield(member)
          end
        end
      end
    end unless defined? old_reader
    self
  end

  def rfm_extend_member(member, extension, i=nil)
    if member and extension
      unless member.instance_variable_get(:@root)
        member.instance_variable_set(:@root, @root)
        member.instance_variable_set(:@parent, self)
        member.instance_variable_set(:@index, i)
        member.instance_eval(){def root; @root; end}
        member.instance_eval(){def parent; @parent; end}
        member.instance_eval(){def get_index; @index; end}
      end
      member.extend(extension)
    end
  end

end # Array

class Hash

  # TODO: Possibly deprecated, delete if not used.
  def rfm_only(*keepers)
    self.dup.each_key {|k| self.delete(k) if !keepers.include?(k)}
  end

  def rfm_filter(*args)
    options = args.rfm_extract_options!
    delete = options[:delete]
    self.dup.each_key do |k|
      self.delete(k) if (delete ? args.include?(k) : !args.include?(k))
    end
  end

  # Convert hash to Rfm::CaseInsensitiveHash
  def to_cih
    new = Rfm::CaseInsensitiveHash.new
    self.each{|k,v| new[k] = v}
    new
  end
end # Hash

# Allows access to superclass object
class SuperProxy
  def initialize(obj)
    @obj = obj
  end

  def method_missing(meth, *args, &blk)
    @obj.class.superclass.instance_method(meth).bind(@obj).call(*args, &blk)
  end
end # SuperProxy


class Time
  # Returns array of [date,time] in format suitable for FMP.
  def to_fm_components(reset_time_if_before_today=false)
    d = self.strftime('%m/%d/%Y')
    t = if (Date.parse(self.to_s) < Date.today) and reset_time_if_before_today==true
          "00:00:00"
        else
          self.strftime('%T')
        end
    [d,t]
  end
end # Time

class String
  def title_case
    self.gsub(/\w+/) do |word|
      word.capitalize
    end
  end
end # String
