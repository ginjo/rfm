module SaxChange
  class Template < Hash
  
    # Usage: Template.register(name-and-or-hash-and-or-block)
    # See intance methods for block-level dsl commands
    
    class << self
      attr_accessor :cache
      
      def register(*args, &block)
        Template.cache.unshift(new(*args, &block)).first
      end
    
      def [](name)
        # constant_name = constants.find(){|c| const_get(c)&.template&.dig('name') == name}
        # constant_name && const_get(constant_name)&.template
        cache.find{|t| t&.dig('name') == name}
      end
      
    end # class << self
    
    @cache = []
      
    attr_accessor :template
    
    
    def initialize(*args)
      hash = args.pop if args.last.is_a?(Hash)
      self['name'] = args[0] if (args[0].is_a?(String) || args[0].is_a?(Symbol))
      merge!(hash) if hash
      instance_eval &proc if block_given?
      #puts "#{self['name']}.#{__callee__} hash_given?: #{!hash.nil?}, block_given? #{block_given?}"
    end
    
    def new_level(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      self.class.new(*args, &block)
    end
    
    def register
      self.class.register(self)
    end
    
    
    ###  Block-level DSL methods
    
    def element(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      (self['elements'] ||= []) << new_level(*args, &block)
    end
    
    def attribute(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      (self['attributes'] ||= []) << new_level(*args, &block)
    end
    
    def attach_attributes_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['attach_attributes_default'] = args[0]
    end
    
    def attach_elements_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['attach_elements_default'] = args[0]
    end    
    
    def compact_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['compact_default'] = args[0]
    end
    
    def create_accessors_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['create_accessors_default'] = args[0]
    end
    
    def attach(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach'] = []
      #self['attach'].concat args
      #self['attach'] << Proc.new if block_given?
      self['attach'] = args[0]
    end
    
    def attach_elements(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['attach_elements'] = args[0]
    end
    
    def attach_attributes(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['attach_attributes'] = args[0]
    end
    
    def delimiter(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['delimiter'] = args[0]
    end
    
    def accessor(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['accessor'] = args[0]
    end
    
    def create_accessors(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['create_accessors'] = args[0]
    end
    
    def as_name(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['as_name'] = args[0]
    end
    
    def compact(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['compact'] = args[0]
    end
    
    def initial_object(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['initial_object'] = args[0]
    end
    
    def before_close(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['before_close'] = args[0]
    end
    
  end # Template
end # SaxChange




