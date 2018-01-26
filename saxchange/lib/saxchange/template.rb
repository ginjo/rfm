module SaxChange
  class Template < Hash
  
    # Usage: Template.register(name-and-or-hash-and-or-block)
    # See intance methods for block-level dsl commands
    
    class << self
      attr_accessor :cache
      
      # Register a new template.
      # Takes name, hash, block. All optional
      def register(*args, &block)
        Template.cache.unshift(new(*args, &block)).first
      end
    
      # Get template from cache, given name == :name
      def [](name)
        # constant_name = constants.find(){|c| const_get(c)&.template&.dig('name') == name}
        # constant_name && const_get(constant_name)&.template
        cache.find{|t| t&.dig('name') == name}
      end
    end # class << self
    
    @cache = []
      
    # I don't think this is used any more, since THIS IS the template now.
    #attr_accessor :template
    
    # Create a new template or sub-template.
    # Takes name, hash, block. All optional.
    def initialize(*args)
      hash = args.pop if args.last.is_a?(Hash)
      self['name'] = args[0] if (args[0].is_a?(String) || args[0].is_a?(Symbol))
      merge!(hash) if hash
      # Note that while the block will be evaluated in this instances context,
      # it will not have access to local variables from this specific method.
      instance_eval &proc if block_given?
      #puts "#{self['name']}.#{__callee__} hash_given?: #{!hash.nil?}, block_given? #{block_given?}"
    end
    
    # Convenience method for 'self.class.new'.
    def new_level(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      self.class.new(*args, &block)
    end
    
    # Manual registration of this template.
    # This is not necessary if using 'Template.register'.
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
      if block_given?
        self['attach'] = proc
      else
        self['attach'] = args[0]
      end
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




