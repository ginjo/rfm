require 'forwardable'
module SaxChange
  
  #####  SAX HANDLER  #####
  
  # TODO: Find out why handler instance template_prefix attribute is empty, even when passing a template thru options.
  
  # A handler instance is created for each parsing run. The handler has several important functions:
  # 1. Receive callbacks from the sax/stream parsing engine (start_element, end_element, attribute...).
  # 2. Maintain a stack of cursors, growing & shrinking, throughout the parsing run.
  # 3. Maintain a Cursor instance throughout the parsing run.
  # 3. Hand over parser callbacks & data to the Cursor instance for refined processing.
  #
  # The handler instance is unique to each different parsing gem but inherits generic
  # methods from this Handler module. During each parsing run, the Hander module creates
  # a new instance of the spcified parer's handler class and runs the handler's main parsing method.
  # At the end of the parsing run the handler instance, along with it's newly parsed object,
  # is returned to the object that originally called for the parsing run (your script/app/whatever).
  # Remember: The template hash keys must be Strings, not Symbols.
  module Handler
    # We stick these methods in front of the specific handler class,
    # so they run before their namesake's in the Handler class.
    # TODO: Find a better place for this module, maybe its own file?
    module PrependMethods
      # We want this 'run_parser' to go before the specific handler's run_parser.
      def run_parser(io)
        SaxChange.log.info("#{self}#run_parser with:'#{io}'") if config[:log_parser]
        raise_if_bad_io(io)
        io = StringIO.new(io) if io.is_a?(String)
        super # calls run_parser in backend-specific handler instance.
        result
      end
    end # PrependMethods
  
    using Refinements
    # Was experimental.
    #using ObjectMergeRefinements

    
    # This might have to be done for each specific handler class,
    # but it seems to work just fine doing it once here.
    prepend Config
    
    extend Forwardable
  
    attr_accessor :stack, :template, :initial_object, :stack_debug, :default_class, :backend, :parser, :errors
      
    def self.included(base)
      base.send :prepend, PrependMethods
      
      # Currently, this is done just in the main Handler class, and it seems to work.
      #base.send :prepend, Config
      
      #base.singleton_class.send :attr_accessor, :label, :file, :setup, :backend_instance, :loaded
    end
    
    def self.new(_backend=nil, _template=nil, _initial_object=nil, **options)
      backend_handler_class = get_backend(_backend || config(options)[:backend])
      #puts "#{self}.new with _backend:'#{_backend}', _template:'#{_template}', _initial_object:'#{_initial_object}', options:'#{options}'"
      #backend_handler_class.new(_template, _initial_object, **options)
      _parser = yield(binding) if block_given?
      handler_object = backend_handler_class.allocate
      handler_object.parser = _parser
      handler_object.send :initialize, _template, _initial_object, **options
      handler_object
    end
      
    # Takes backend symbol and returns custom Handler class for specified backend.
    # TODO: Should this be private? Should it accept options?
    #def self.get_backend(parser_backend = config[:backend])
    def self.get_backend(_backend = nil)
      (_backend = decide_backend) unless _backend
      #puts "Handler.get_backend _backend: #{_backend}"
      if _backend.is_a?(String) || _backend.is_a?(Symbol)
        _backend = extract_handler_name_from_filename _backend
        class_name = _backend.split(/[\-_]/).map{|i| i.capitalize}.join.to_s + "Handler"
        const_defined?(class_name) || require("saxchange/handler/#{_backend}_handler.rb")
        backend_handler_class = const_get(class_name)
      else
        backend_handler_class = _backend
      end
      #puts "Handler.get_backend backend_handler_class: #{backend_handler_class}"
      backend_handler_class
    end
  
    # Finds a loadable backend and returns its name.
    # Search is alphebetical.
    # TODO: Should this be private? Take options?
    def self.decide_backend
      list_handlers.find do |fname|
        name = extract_handler_name_from_filename fname
        Gem::Specification::find_all_by_name(name).any?
      end || 'rexml'
    end
    
    def self.extract_handler_name_from_filename(filename=nil)
      regex = /_handler\.rb/
      filename ? filename.to_s.gsub(regex, '') : regex
    end
    
    def self.list_handlers
      @handlers ||= Dir.entries(File.join(File.dirname(__FILE__), "handler/")).delete_if(){|f| !f[/[a-zA-Z0-9]/]}
    end
    

    ###  Instance Methods  ###
  
    # The Handler#initialize is the final say for pushing options to the handler automatically.
    # After #initialize, one must manually change config or attributes, if they really want to.
    # The next step expected after #initialize is run_parser.
    def initialize(_template=nil, _initial_object=nil, **options)
      #puts "Handler#initialize with options: #{options}"
      @errors = []
      _template ||= config[:template]
      @template = get_template(_template, config)
      _initial_object ||= config[:initial_object] || (@template && @template['initial_object'])
      @initial_object = case
        when _initial_object.nil?; config[:default_class].new
        when _initial_object.is_a?(Class); _initial_object.new(**config) # added by wbr for v4
        when _initial_object.is_a?(String); eval(_initial_object)
        when _initial_object.is_a?(Symbol); self.class.const_get(_initial_object).new(**config) # added by wbr for v4
        when _initial_object.is_a?(Proc); _initial_object.call(self)
        else _initial_object
      end
      @stack = []
      @stack_debug=[]
      
      # Experimental cache config
      @config_cache = config

      set_cursor Cursor.new('__TOP__', self, **options).process_new_element
      #puts "Handler#initialize done: #{self.to_yaml}"
    end
    
    def default_template
      {'compact'=>true}
    end
        
    # Takes string, symbol, or hash, and returns a (possibly cached) parsing template.
    def get_template(_template=nil, _template_prefix=nil, _template_cache=nil, **options)  #_template_prefix=config[:template_prefix])
      _template ||= options[:template] || config[:template] || default_template
      
      # This is what it boils down to now, simple call to an array of templates.
      #
      #####
      puts "Getting template for '#{_template}'"
      self.template = if _template.is_a?(Proc)
        Template[_template.call(options, binding).to_s]
      else
        Template[_template]
      end
      puts "Template retrieved '#{template}' "
      return template
      #####
      
      #####  Logical End of Method  #####
      
      #   #puts "#{self}#get_template using _template: #{_template}"
      #   return _template unless ['String', 'Symbol', 'Proc'].include?(_template.class.name.split('::').last.to_s)
      #   
      #   file_name = case
      #     when _template.is_a?(Proc); _template.call(options, binding)
      #     when _template.to_s[/\.[yx].?ml$/i]; _template.to_s
      #     when _template.is_a?(Symbol); _template.to_s + '.yml'
      #     else raise "Template '#{_template}' cannot be found."
      #   end
      #   # Return a template-object (or nil) if proc resolved to anything other than string.
      #   return default_template unless file_name
      #   return file_name unless file_name.is_a?(String)
      #   load_template(file_name, _template_prefix, _template_cache, **options)  #, **options)
    end

    #   # Does the heavy-lifting of template retrieval.
    #   # template_cache is a reference to any cache of templates (a hash),
    #   # but it should generally be a Parser#@templates ivar, if possible.
    #   def load_template(file_name, _template_prefix=nil, _template_cache=nil, **options)  #, **options)
    #     return default_template unless file_name.to_s.size > 0
    #     #puts "LOAD_TEMPLATE name: '#{file_name}', prefix: '#{_template_prefix}'"
    #     _template_prefix ||= options[:template_prefix] || config[:template_prefix]
    #     _template_cache ||= (parser && parser.templates) || default_template
    #     #puts "PARSERID: #{parser.object_id}"
    #     #puts "PARSERTEMPLATESID: #{parser.templates.object_id}"
    #     #puts "TEMPLATECACHEID: #{_template_cache.object_id}, #{_template_cache}"
    #     _template_cache[file_name] ||= case
    #       when file_name.to_s[/\.y.?ml$/i]; (YAML.load_file(File.join(*[_template_prefix, file_name].compact)))
    #        # This line might cause an infinite loop.
    #        # TODO: Update this template-selection matcher for rfm v4.
    #        #       The 'self.class.build' is leftover from monolithic parser/handler in v3.
    #        # when name.to_s[/\.xml$/i]; self.class.build(File.join(*[_template_prefix, name].compact), nil, {'compact'=>true})
    #       else config.merge(options)[:default_class].new
    #     end
    #     #puts "#{self}.load_template loaded: #{_template_cache[file_name]}"
    #     _template_cache[file_name]
    #   rescue #:error
    #     SaxChange.log.warn "SaxChange::Parser#load_template '#{file_name}' raised exception: #{$!}"
    #     default_template
    #   end
    
    # Call this from each backend 'run_parser' method.
    # Be careful - calling io.eof? can raise errors if io is not in proper state.
    def raise_if_bad_io(io)
      #SaxChange.log.info("Handler#raise_if_bad_io io.closed?: '#{io.closed?}'") #if config[:log_parser]
      if io.is_a?(IO) && ( io.closed? || (io.is_a?(File) && io.eof?) )
        SaxChange.log.warn "#{self} could not execute 'run_parser'. The io object is closed or eof: #{io}"
        io.rewind if io.is_a?(File)
      end
    end
  
    def result
      stack[0].object if stack[0].is_a? Cursor
    end
  
    def cursor
      stack.last
    end
  
    # Insert cursor into stack. Returns cursor.
    def set_cursor(args) # cursor_object
      #puts "Pushing cursor into stack #{args}"
      if args.is_a? Cursor
        stack.push(args)
        @stack_debug.push(args.dup.tap(){|c| c.handler = c.handler.object_id})  #; c.parent = c.parent.tag})
      end
      cursor
    end
  
    def dump_cursor
      stack.pop
    end
  
    def top
      stack[0]
    end
  
    def transform(name)
      return name unless config[:tag_translation].is_a?(Proc)
      config[:tag_translation].call(name.to_s)
    end
  
    # Add a node to an existing element.
    def _start_element(tag, attributes=nil, *args)
      #puts ["_START_ELEMENT", tag, attributes, args]  #.to_yaml # if tag.to_s.downcase=='fmrestulset'
      tag = transform tag
      if attributes
        # This crazy thing transforms attribute keys to underscore (or whatever).
        #attributes = default_class[*attributes.collect{|k,v| [transform(k),v] }.flatten]
        # This works but downcases all attribute names - not good.
        attributes = config[:default_class].new.tap {|hash| attributes.each {|k, v| hash[transform(k)] = v}}
        # This doesn't work yet, but at least it wont downcase hash keys.
        #attributes = Hash.new.tap {|hash| attributes.each {|k, v| hash[transform(k)] = v}}
      end
      set_cursor cursor.receive_start_element(tag, attributes)
    end
  
    # Add attribute to existing element.
    def _attribute(name, value, *args)
      #puts "_ATTRIBUTE '#{name}' with value '#{value}', args '#{args}'"
      name = transform name
      cursor.receive_attribute(name, value)
    end
  
    # Add 'content' attribute to existing element.
    def _text(value, *args)
      #puts "_TEXT '#{value}', '#{args}'"
      #puts RUBY_VERSION_NUM
      if RUBY_VERSION_NUM > 1.8 && value.is_a?(String)
        #puts "Forcing utf-8"
        value.force_encoding('UTF-8')
      end
      # I think the reason this was here is no longer relevant, so I'm disabeling.
      return unless value[/[^\s]/]
      cursor.receive_attribute(config[:text_label], value)
    end
  
    # Close out an existing element.
    def _end_element(tag, *args)
      tag = transform tag
      #puts "_END_ELEMENT '#{tag}', '#{args}'"
      cursor.receive_end_element(tag) && dump_cursor
    end
  
    def _doctype(*args)
      #puts "_DOCTYPE '#{args}'"
      if args[0].is_a?(Hash)
        _start_element('doctype', args[0])
      else
        (args = args[0].gsub(/"/, '').split) if args.size ==1
        _start_element('doctype', :values=>args)
      end
      _end_element('doctype')
    end
    
    def _cdata(string)
      #puts "_CDATA '#{string}'"
      _start_element('cdata', config[:text_label] => string)
      _end_element('cdata')
    end
    
    def _error(*args)
      #puts "_ERROR '#{args}'"
      errors << [args]
      SaxChange.log.warn "#{self}##{__callee__} : #{args}"
    end
    
    def _xmldecl(*args)
      #puts "_XMLDECL '#{args}'"
      if args[0].is_a?(Hash)
        _start_element('xmldecl', args[0])
      else
        _start_element('xmldecl', {'version'=>args[0], 'encoding'=>args[1], 'standalone'=>args[2]})
      end
      _end_element('xmldecl')
    end
    
    def print_stack_debug
      #stack_debug.each{|c| puts (" " * c.level) +  "Cursor '#{c.tag}', model '#{c.model['name']}', logical_parent '#{c.logical_parent.tag}', logical_parent_model '#{c.logical_parent_model&.dig('name')}', attach '#{c&.model.dig('attach')}', object '#{c.object.class}'"}; nil
      stack_debug.each{|c| puts (" " * c.level) +  "Cursor '#{c.tag}', logical_parent '#{c.logical_parent&.tag}', xml_parent '#{c.xml_parent&.tag}'"}; nil
    end
    
  
  end # Handler
  


end # SaxChange