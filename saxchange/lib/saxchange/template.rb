require 'yaml'

module SaxChange
  class Template < Hash
  
    # Usage: Template.register(name-and-or-hash-and-or-block)
    # See instance methods for block-level dsl commands.
    # Provide a name to the #register method, or declare the
    # 'name' in the top-level of the template-hash.
    #
    # This DSL helps build a template model hash-tree of parsing instructions for the sax parser.
    # The object you construct with this DSL will look similar to the desired
    # output of the sax parsing run.
    # It is not necessary to use this DSL. A plain ruby hash, a yaml document, or
    # even an xml document can be used to build the template model.
    #
    # Example with DSL:
    # SaxChange::Template.register('my_template_name') do
    #   element 'data' do
    #     initial_object Hash
    #     as_name 'top_level_data'
    #     attribute 'type' do
    #       as_name 'data_type'
    #       attach do |env|
    #         do-stuff-here-to-manually-attach
    #       end
    #     end
    #   element 'meta' do
    #     ...
    #   end
    # end
    #
    #
    # Example with YAML:
    # SaxChange::Template.register('my_template_name', YAML.load(<<-EEOOFF))
    # ---
    # elements:
    # - name: data
    #   initial_object: proc {Hash.new}
    #   as_name: top_level_data
    #   ...
    # - name: meta
    #   ...
    #
    #
    class << self
      attr_accessor :cache
      
      # Register a new template.
      # Takes name, hash, block. All optional
      def register(*args, &block)
        #puts "\nTemplate#register '#{args[0] if args[0].is_a?(String)}'"
        #puts args.to_yaml
        Template.cache.unshift(new(*args, &block)).first.render_settings
      end
      
      def register_yaml(*args)
        hash = args.last.is_a?(Hash) ? args.pop : {}
        yaml = args.pop
        template = YAML.load(yaml).merge(hash)
        register(*args, template)
      end

      def register_xml(*args)
        hash = args.last.is_a?(Hash) ? args.pop : {}
        xml = args.pop
        template = Parser.parse(xml, backend:'rexml', template:{'compact_default'=>true}).merge(hash)
        register(*args, template)
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
    # Use this method if you have a template model hash-tree
    # that you want to register (and then refer to by name when parsing).
    # √ TODO: Allow one arg 'name' to be passed with this method.
    def register(*args)
      self.class.register(*args, self)
    end
    
    # Recursively traverse template keys/values & all element/attribute children,
    # eval'ing each qualifying string value into a proc.
    # TODO: I think 'skip' might not be used ('none' really means 'skip', while 'hidden'
    # means just don't attach).
    def render_settings
      each do |k,v|
        case
        when %w(initial_object object before_close).include?(k)
          self[k] = eval_setting(v)
        when %w(attach).include?(k)
          self[k] = eval_setting(v, *%w( private shared hash array none values default hidden ))
        when %w(attach_elements attach_attributes).include?(k)
          self[k] = eval_setting(v, *%w( private shared hash array none values default skip ))
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
    # This is used in recursive 'render_settings' to
    # to convert entire hash-tree to template-tree.
    # The conversion is only really necessary for building
    # the model from string-based settings. A properly contructed plain-hash
    # template model is a perfectly valid parsing template.
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
    
    # Declare an element.
    def element(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      (self['elements'] ||= []) << new_level(*args, &block)
    end
    
    # Declare an attribute.
    def attribute(*args, &block)
      #puts "#{self}.#{__callee__} #{args}"
      (self['attributes'] ||= []) << new_level(*args, &block)
    end
    
    # Template-wide default attachment setting for attributes.
    def attach_attributes_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_attributes_default'] = args[0]
      if block_given?
        self['attach_attributes_default'] = proc
      else
        self['attach_attributes_default'] = args[0]
      end
    end
    
    # Template-wide default attachment setting for elements.
    def attach_elements_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_elements_default'] = args[0]
      if block_given?
        self['attach_elements_default'] = proc
      else
        self['attach_elements_default'] = args[0]
      end
    end    
    
    # Template-wide default 'compact' setting.
    def compact_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['compact_default'] = args[0]
    end
    
    # Template-wide default 'create_accessors' setting.
    def create_accessors_default(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['create_accessors_default'] = args[0]
    end
    
    # Attachment setting for an element or an attribute.
    # Pass a block to manually manipulate the object.
    # A nil block-result will skip automatic attachment,
    # while any other block-result will be interpreted as
    # an attachment setting.
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
    
    # Element-wide attachment setting for all sub-elements
    # being attached to this object.
    def attach_elements(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_elements'] = args[0]
      if block_given?
        self['attach_elements'] = proc
      else
        self['attach_elements'] = args[0]
      end
    end
    
    # Element-wide attachment setting for all attributes
    # being attached to this object.    
    def attach_attributes(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['attach_attributes'] = args[0]
      if block_given?
        self['attach_attributes'] = proc
      else
        self['attach_attributes'] = args[0]
      end
    end
    
    # Name of hash key or ivar whose data to use
    # as a uniq identifier for an otherwise non-uniq
    # element tag.
    def delimiter(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['delimiter'] = args[0]
    end
    
    # Create accessor method for this element or attribute.
    def accessor(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['accessor'] = args[0]
    end
    
    # Create accessors for all elements or attributes
    # attached to this object.
    def create_accessors(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['create_accessors'] = args[0]
    end
    
    # Change the name of an element or attribute.
    def as_name(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['as_name'] = args[0]
    end
    
    # Attempt to compact recursive trees of
    # single-element nodes.
    def compact(*args)
      #puts "#{self}.#{__callee__} #{args}"
      self['compact'] = args[0]
    end
    
    # The object class, or proc, or actual object
    # to be defined for this element.
    def initial_object(*args)
      #puts "#{self}.#{__callee__} #{args}"
      #self['initial_object'] = args[0]
      if block_given?
        self['initial_object'] = proc
      else
        self['initial_object'] = args[0]
      end
    end
    
    # Callback proc/block to be run during 'on-element-close-tag'
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

