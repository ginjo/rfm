module SaxChange
  module Template
      
    attr_accessor :template
    
    def document(*args)
      puts "#{self}.#{__callee__} #{args}"
      _template = enhanced_hash(Hash.new)
      _template['name'] = args[0]
      _template.instance_eval &proc if block_given?
      self.template = _template
    end
    
    def attach_attributes_default(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['attach_attributes_default'] = args[0]
    end
    
    def attach_elements_default(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['attach_elements_default'] = args[0]
    end    
    
    def compact_default(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['compact_default'] = args[0]
    end
    
    def create_accessors_default(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['create_accessors_default'] = args[0]
    end
    
    def element(*args)
      puts "#{self}.#{__callee__} #{args}"
      new_element = enhanced_hash(Hash.new).merge!('name' => args[0])
      new_element.instance_eval &Proc.new if block_given?
      (self['elements'] ||= []) << new_element
    end
    
    def attribute(*args)
      puts "#{self}.#{__callee__} #{args}"
      new_attr = enhanced_hash(Hash.new).merge!('name' => args[0])
      new_attr.instance_eval &Proc.new if block_given?
      (self['attributes'] ||= []) << new_attr
    end
    
    def attach(*args)
      puts "#{self}.#{__callee__} #{args}"
      #self['attach'] = []
      #self['attach'].concat args
      #self['attach'] << Proc.new if block_given?
      self['attach'] = args[0]
    end
    
    def attach_elements(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['attach_elements'] = args[0]
    end
    
    def attach_attributes(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['attach_attributes'] = args[0]
    end
    
    def delimiter(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['delimiter'] = args[0]
    end
    
    def accessor(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['accessor'] = args[0]
    end
    
    def create_accessors(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['create_accessors'] = args[0]
    end
    
    def as_name(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['as_name'] = args[0]
    end
    
    def compact(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['compact'] = args[0]
    end
    
    def initial_object(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['initial_object'] = args[0]
    end
    
    def before_close(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['before_close'] = args[0]
    end
    
    def enhanced_hash(hash)
      hash.singleton_class.send :include, Template
      hash
    end
            
  end # Template
end




