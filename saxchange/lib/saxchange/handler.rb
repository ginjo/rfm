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
  
    attr_accessor :stack, :template, :initial_object, :stack_debug, :parser
      
    prepend Config
  
    def self.included(base)
      base.send :prepend, Config
    end
   
  
    ###  Instance Methods  ###
  
    def initialize(_template=nil, _initial_object=nil, **options)
      config options
    
      @template = _template || config[:template]
      
      #_initial_object = _initial_object || config[:initial_object] || @template['initial_object']
      #config[:initial_object] ||= _initial_object || @template[:initial_object]
      _initial_object ||= config[:initial_object] || (@template && @template['initial_object'])
      
      puts "#{self} _initial_object: '#{_initial_object}'"
      @initial_object = case
        when _initial_object.nil?; config[:default_class].new
        when _initial_object.is_a?(Class); _initial_object.new
        when _initial_object.is_a?(String); eval(_initial_object)
        when _initial_object.is_a?(Symbol); self.class.const_get(_initial_object).new
        when _initial_object.is_a?(Proc); _initial_object.call(self)
        else _initial_object
      end
      @stack = []
      @stack_debug=[]

      #puts "NEW HANDLER #{self}"
      #puts self.to_yaml
      set_cursor Cursor.new('__TOP__', self).process_new_element
    end

    # # TODO: All template management should be at the parser instance level, not here in the handler.
    # #
    # # Takes string, symbol, or hash, and returns a (possibly cached) parsing template.
    # # String can be a file name, yaml, xml.
    # # Symbol is a name of a template stored in Parser@templates (you would set the templates when your app or gem loads).
    # # Templates stored in the Parser@templates var can be strings of code, file specs, or hashes.
    # # The Handler@template
    # def get_template(_template)
    #   puts "HANDLER#get_template with _template: '#{_template}'"
    #   puts "HANDLER @templates: #{@templates}"
    #   #   dat = templates[name]
    #   #   if dat
    #   #     rslt = load_template(dat)
    #   #   else
    #   #     rslt = load_template(name)
    #   #   end
    #   #   (templates[name] = rslt) #unless dat == rslt
    #   # The above works, but this is cleaner.
    #   #config[:templates].tap {|templates| templates[name] = templates[name] && load_template(templates[name]) || load_template(name) }
    #   # And this is more readable.
    #   return _template if _template.is_a?(Hash)
    #   template = @templates[_template] = (
    #     @templates[_template] && load_template(@templates[_template]) \
    #   ||
    #     load_template(_template)
    #   )
    #   template
    # end
    # 
    # # Does the heavy-lifting of template retrieval.
    # def load_template(dat)
    #   rslt = case
    #     when dat.is_a?(Hash); dat
    #     when (dat.is_a?(String) && dat[/^\//]); YAML.load_file dat
    #     when dat.to_s[/\.y.?ml$/i]; (YAML.load_file(File.join(*[template_prefix, dat].compact)))
    #      # This line might cause an infinite loop.
    #     when dat.to_s[/\.xml$/i]; self.class.build(File.join(*[template_prefix, dat].compact), nil, {'compact'=>true})
    #     when dat.to_s[/^<.*>/i]; "Convert from xml to Hash - under construction"
    #     when dat.is_a?(String); YAML.load dat
    #     else config[:default_class].new
    #   end
    #   #puts rslt
    #   rslt
    # end
  
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
      return name unless config[:tag_translation].is_a?(Proc)
      config[:tag_translation].call(name.to_s)
    end
  
    # Add a node to an existing element.
    def _start_element(tag, attributes=nil, *args)
      #puts ["_START_ELEMENT", tag, attributes, args].to_yaml # if tag.to_s.downcase=='fmrestulset'
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
      cursor.receive_attribute(config[:text_label], value)
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