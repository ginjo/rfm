module SaxChange
  module Template
    ###  Extend this module in any class or module that you want
    ###  to behave as a template for this sax parser.
    
    # 
    # TODO: Load plain ruby hashes from file:
    #       SaxChange::Template.instance_eval{templates.unshift(eval(File.read('test_sax_template_ruby.rb')))}
    # TODO: Load yaml templates from file:
    #       SaxChange::Template.instance_eval{templates.unshift(YAML.load_file(SaxChange::Config.config[:template_prefix].to_s + 'fmpxmllayout.yml'))}
    # TODO: Move handler template methods to here, but retain ability to cache the templates in any array (or hash?).
    #       The ability to cache templates anywhere might just be limited to yaml and plain-ruby templates.
    #       The DSL templates should really be cached globally, since they're module/class based.
    # TODO: Consider dropping ability to cache templates anywhere. If templates can be named by user,
    #       they can safely be cached in main Template cache.
    #
    
    ###  Module methods just for this module
    
    class << self
      attr_accessor :cache
    
      def [](name)
        # constant_name = constants.find(){|c| const_get(c)&.template&.dig('name') == name}
        # constant_name && const_get(constant_name)&.template
        cache.find{|t| t&.dig('name') == name}
      end
      
    end # class << self
    
    @cache = []
      
    attr_accessor :template
    
    
    ###  Methods to be extended by other Module or Class.
    
    # TODO: Should this be renamed 'template'?
    # TODO: Potential functionality:
    # given yaml string: loads yaml.
    # given any other string: is name of template.
    # given hash: inserts hash into cache.
    # given name, hash: inserts hash into cache.
    # given block: evaluates as Template DSL.
    # given nothing: returns cached template object.
    #
    def document(*args, **options)
      #puts "#{self}.#{__callee__} #{args}"
      opts = args.pop if args.last.is_a?(Hash)
      _template = enhanced_hash(Hash.new)
      _template['name'] = args[0] if (args[0].is_a?(String) || args[0].is_a?(Symbol))
      _template.merge!(opts) if opts
      _template.instance_eval &proc if block_given?
      self.template = _template
      #puts "#{self}.document _template: #{_template['name']}"
      Template.cache.unshift _template
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
    
    def element(*args)
      #puts "#{self}.#{__callee__} #{args}"
      new_element = enhanced_hash(Hash.new).merge!('name' => args[0])
      new_element.instance_eval &Proc.new if block_given?
      (self['elements'] ||= []) << new_element
    end
    
    def attribute(*args)
      #puts "#{self}.#{__callee__} #{args}"
      new_attr = enhanced_hash(Hash.new).merge!('name' => args[0])
      new_attr.instance_eval &Proc.new if block_given?
      (self['attributes'] ||= []) << new_attr
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
    
    def enhanced_hash(hash)
      hash.singleton_class.send :include, Template
      hash
    end
    
    extend self
    
  end # Template
end # SaxChange




