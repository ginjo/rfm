module SaxChange
  module Config
    @defaults = {}
  
    def self.included(other, *args)
      other.instance_eval do
        singleton_class.send :attr_accessor, :defaults
        @defaults ||= Config.defaults || {}
        attr_accessor :defaults
        extend Config
        
        #puts "#{self} included Config"  # and has @defaults: #{other.instance_variable_get(:@defaults)}"
      end
    end # included
    
    
    def config(**opts)
      if opts.any? || @defaults.nil?
      
        upstream = if self.is_a?(Class) || self.is_a?(Module)
          #puts "#{self} is CLASS, using Config.defaults #{Config.defaults}"
          Config.defaults
        else
          #puts "#{self} is INSTANCE. Using self.class.defaults #{self.class.defaults}"
          self.class.defaults
        end
        
        @defaults = (@defaults || {}).merge(upstream).merge(opts)
      else
        @defaults
      end
    end
    
    def initialize(opts={caller:self})
      #puts "#{self.class.name}#initialize, opts: #{opts}"
      config(**opts)
    end
    
    included self
  end # Config
end # SaxChange