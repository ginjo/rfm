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
  module Handler
  
    attr_accessor :stack, :template, :initial_object, :stack_debug, :template_prefix
  
    #Parser.install_defaults(self)
    
    include Config
  
  
    ###  Class Methods  ###
  
    # Main parsing interface (also aliased at Parser.parse)
    # options: template:nil, initial_object:nil, parser:nil, ... 
    def self.build(io='', **options) #template=nil, initial_object=nil, parser=nil, options={})
      puts "Handler.build options: #{options}"
      parser_backend = options[:parser] || defaults[:backend]
      template = options[:template]
      initial_object = options[:initial_object]
      handler_class = get_backend(parser_backend)
      (SaxChange.log.info "Using backend parser: #{handler_class}, with template: #{template}") if options[:log_parser]
      if block_given?
        #puts "Handler.build block_given!"
        handler_class.build(io, **options, &Proc.new)
      else
        #puts "Handler.build no block given"
        handler_class.build(io, **options)
      end
    end
    
    # This works whereas class << self does not appear to.
    # These alias definitions must go after the original method def.
    # Turns out these aren't needed here. Only 'build' should exist on Handler class.
    # singleton_class.send :alias_method, :call, :build
    # singleton_class.send :alias_method, :parse, :build
  
    def self.included(base)
      # Adds a .build method to the custom handler instance, when the generic Handler module is included.
      def base.build(io='', **options)  # template=nil, initial_object=nil)
        handler = new(options[:template], options[:initial_object])
        # The block options was experimental but is not currently used for rfm,
        # all the block magic happens in Connection.
        if block_given?
          #puts "#{self.name}.build block_given!"
          #handler.run_parser(io, &Proc.new)
          yield(handler)
        else
          #puts "#{self.name}.build no block given"
          handler.run_parser(io)
        end
        
        handler
      end # base.build
      
      # def base.included(other_other)
      #   other_other.send :include, Config
      # end
      base.send :include, Config
      
      #super
    end # self.included
  
    # Takes backend symbol and returns custom Handler class for specified backend.
    def self.get_backend(parser_backend=defaults[:backend])
      (parser_backend = decide_backend) unless parser_backend
      puts "PARSER_BACKEND: #{parser_backend}"
      if parser_backend.is_a?(String) || parser_backend.is_a?(Symbol)
        parser_proc = PARSERS[parser_backend.to_sym][:proc]
        parser_proc.call unless parser_proc.nil? || const_defined?((parser_backend.to_s.capitalize + 'Handler').to_sym)
        const_get(parser_backend.to_s.capitalize + "Handler")
      end
    rescue
      raise "Could not load the backend parser '#{parser_backend}': #{$!}"
    end
  
    # Finds a loadable backend and returns its symbol.
    def self.decide_backend
      #BACKENDS.find{|b| !Gem::Specification::find_all_by_name(b[1]).empty? || b[0]==:rexml}[0]
      PARSERS.find{|k,v| !Gem::Specification::find_all_by_name(v[:file]).empty? || k == :rexml}[0]
    rescue
      puts "Handler.decide_backend raising #{$!}"
      raise "The xml parser could not find a loadable backend library: #{$!}"
    end
  
  
  
    ###  Instance Methods  ###
  
    def initialize(_template=nil, _initial_object=nil, **options)
      puts "Initializing #{self} with _template: #{_template}, _initial_object: #{_initial_object}, options: #{options}"
      config options
      
      @initial_object = case
                        when _initial_object.nil?; config[:default_class].new
                        when _initial_object.is_a?(Class); _initial_object.new
                        when _initial_object.is_a?(String) || _initial_object.is_a?(Symbol); get_constant(_initial_object).new
                        else _initial_object
                        end
      @stack = []
      @stack_debug=[]
      @template_prefix = options[:template_prefix] || defaults[:template_prefix] || ''
      @template = get_template(_template)
      #puts "NEW HANDLER #{self}"
      #puts self.to_yaml
      set_cursor Cursor.new('__TOP__', self).process_new_element
    end
  
    # Takes string, symbol, hash, and returns a (possibly cached) parsing template.
    # String can be a file name, yaml, xml.
    # Symbol is a name of a template stored in Parser@templates (you would set the templates when your app or gem loads).
    # Templates stored in the Parser@templates var can be strings of code, file specs, or hashes.
    def get_template(name)
      #   dat = templates[name]
      #   if dat
      #     rslt = load_template(dat)
      #   else
      #     rslt = load_template(name)
      #   end
      #   (templates[name] = rslt) #unless dat == rslt
      # The above works, but this is cleaner.
      self.class.defaults[:templates].tap {|templates| templates[name] = templates[name] && load_template(templates[name]) || load_template(name) }
      template = defaults[:templates][name]
      defaults[:template] = template
    end
  
    # Does the heavy-lifting of template retrieval.
    def load_template(dat)
      rslt = case
             when dat.is_a?(Hash); dat
             when (dat.is_a?(String) && dat[/^\//]); YAML.load_file dat
             when dat.to_s[/\.y.?ml$/i]; (YAML.load_file(File.join(*[template_prefix, dat].compact)))
               # This line might cause an infinite loop.
             when dat.to_s[/\.xml$/i]; self.class.build(File.join(*[template_prefix, dat].compact), nil, {'compact'=>true})
             when dat.to_s[/^<.*>/i]; "Convert from xml to Hash - under construction"
             when dat.is_a?(String); YAML.load dat
             else defaults[:default_class].new
             end
      #puts rslt
      rslt
    end
  
    def result
      stack[0].object if stack[0].is_a? Cursor
    end
  
    def cursor
      stack.last
    end
  
    def set_cursor(args) # cursor_object
      if args.is_a? Cursor
        stack.push(args)
        #@stack_debug.push(args.dup.tap(){|c| c.handler = c.handler.object_id; c.parent = c.parent.tag})
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
      return name unless defaults[:tag_translation].is_a?(Proc)
      defaults[:tag_translation].call(name.to_s)
    end
  
    # Add a node to an existing element.
    def _start_element(tag, attributes=nil, *args)
      #puts ["_START_ELEMENT", tag, attributes, args].to_yaml # if tag.to_s.downcase=='fmrestulset'
      tag = transform tag
      if attributes
        # This crazy thing transforms attribute keys to underscore (or whatever).
        #attributes = default_class[*attributes.collect{|k,v| [transform(k),v] }.flatten]
        # This works but downcases all attribute names - not good.
        attributes = defaults[:default_class].new.tap {|hash| attributes.each {|k, v| hash[transform(k)] = v}}
        # This doesn't work yet, but at least it wont downcase hash keys.
        #attributes = Hash.new.tap {|hash| attributes.each {|k, v| hash[transform(k)] = v}}
      end
      set_cursor cursor.receive_start_element(tag, attributes)
    end
  
    # Add attribute to existing element.
    def _attribute(name, value, *args)
      #puts "Receiving attribute '#{name}' with value '#{value}'"
      name = transform name
      cursor.receive_attribute(name, value)
    end
  
    # Add 'content' attribute to existing element.
    def _text(value, *args)
      #puts "Receiving text '#{value}'"
      #puts RUBY_VERSION_NUM
      if RUBY_VERSION_NUM > 1.8 && value.is_a?(String)
        #puts "Forcing utf-8"
        value.force_encoding('UTF-8')
      end
      # I think the reason this was here is no longer relevant, so I'm disabeling.
      return unless value[/[^\s]/]
      cursor.receive_attribute(defaults[:text_label], value)
    end
  
    # Close out an existing element.
    def _end_element(tag, *args)
      tag = transform tag
      #puts "Receiving end_element '#{tag}'"
      cursor.receive_end_element(tag) and dump_cursor
    end
  
    def _doctype(*args)
      (args = args[0].gsub(/"/, '').split) if args.size ==1
      _start_element('doctype', :value=>args)
      _end_element('doctype')
    end
  
  end # Handler
  


end # SaxChange