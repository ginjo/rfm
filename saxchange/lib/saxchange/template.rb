module SaxChange
  class Template < Hash
  
    # Usage: Template.register(name-and-or-hash-and-or-block)
    # See intance methods for block-level dsl commands
    
    class << self
      attr_accessor :cache
      
      # Register a new template.
      # Takes name, hash, block. All optional
      def register(*args, &block)
        Template.cache.unshift(new(*args, &block)).first.render_settings
      end
    
      # Get template from cache, given name == :name
      def [](name)
        # constant_name = constants.find(){|c| const_get(c)&.template&.dig('name') == name}
        # constant_name && const_get(constant_name)&.template
        cache.find{|t| t&.dig('name') == name}
      end
    end # class << self
    
    @cache = []
      
    
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
    
    # Recursively traverse template keys/values & all element/attribute children,
    # evaling each qualifying string value.
    def render_settings
      each do |k,v|
        case
        when %w(initial_object object before_close).include?(k)
          self[k] = eval_setting(v)
        when %w(attach attach_elements attach_attributes).include?(k)
          self[k] = eval_setting(v, *%w( private shared hash array none values cursor default skip ))
        when %w(elements attributes).include?(k)
          v.is_a?(Array) && templateize_array_hashes(v)
          v.each{|t| t.is_a?(self.class) && t.render_settings}
        end
      end
      self
    end
    
    # If input to setting is String and does not match list
    # of reserved words, then eval it.
    def eval_setting(setting, *skip_reserved_words)
      # TODO: Move the underscore-private-ivar-name-indicator condition to somewhere else.
      rslt = if setting.is_a?(String) && !skip_reserved_words.include?(setting) && !setting[/^_/]
        eval(setting)
      else
        setting
      end
      #puts "Template#eval_setting for '#{self['name']}', raw-setting '#{setting}', reserved-words '#{skip_reserved_words}', rslt '#{rslt}'"
      rslt
    end

    # Change plain-hash template into Template.
    def templateize_array_hashes(array)
      array.collect! do |h|
        if h.is_a?(self.class)
          h
        elsif h.is_a?(Hash)
          self.class.new(h)
        else
          h
        end
      end
    end
    
    
    ###  Template DSL methods
    
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
      #self['attach_attributes_default'] = args[0]
      if block_given?
        self['attach_attributes_default'] = proc
      else
        self['attach_attributes_default'] = args[0]
      end
    end
    
    def attach_elements_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_elements_default'] = args[0]
      if block_given?
        self['attach_elements_default'] = proc
      else
        self['attach_elements_default'] = args[0]
      end
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
      #self['attach_elements'] = args[0]
      if block_given?
        self['attach_elements'] = proc
      else
        self['attach_elements'] = args[0]
      end
    end
    
    def attach_attributes(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_attributes'] = args[0]
      if block_given?
        self['attach_attributes'] = proc
      else
        self['attach_attributes'] = args[0]
      end
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
      #self['initial_object'] = args[0]
      if block_given?
        self['initial_object'] = proc
      else
        self['initial_object'] = args[0]
      end
    end
    
    def before_close(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['before_close'] = args[0]
      if block_given?
        self['before_close'] = proc
      else
        self['before_close'] = args[0]
      end
    end

    
  end # Template
end # SaxChange




