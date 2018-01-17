

module SaxChange
  module Template
    
    attr_accessor :template
    
    def document(*args)
      self.template = TemplateHash.new
      puts "#{self}.#{__callee__} #{args}"
      template = TemplateHash.new
      template['name'] = args[0]
      template['elements'] = []
      template['attributes'] = []
      template.instance_eval &proc if block_given?
      self.template = template
    end
    
    def element(*args)
      puts "#{self}.#{__callee__} #{args}"
      new_element = TemplateHash.new.merge!('name' => args[0])
      new_element['elements'] = []
      new_element['attributes'] = []
      new_element.instance_eval &Proc.new if block_given?
      self['elements'] << new_element
    end
    
    def attribute(*args)
      puts "#{self}.#{__callee__} #{args}"
      new_attr = TemplateHash.new.merge!('name' => args[0])
      new_attr.instance_eval &Proc.new if block_given?
      self['attributes'] << new_attr
    end
    
    def attach(*args)
      puts "#{self}.#{__callee__} #{args}"
      self['attach'] = []
      self['attach'].concat args
      self['attach'] << Proc.new if block_given?
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
      self['before_close'] = args
    end
            
  end # Template


  class TemplateHash < Hash
    extend Template
    include Template
  end
  
end




