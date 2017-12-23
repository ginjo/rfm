# encoding: UTF-8
# Encoding is necessary for Ox, which appears to ignore character encoding.
# See: http://stackoverflow.com/questions/11331060/international-chars-using-rspec-with-ruby-on-rails
#
# ####  A declarative SAX parser, written by William Richardson  #####
#
# This XML parser builds a result object from callbacks sent by any ruby sax/stream parsing
# engine. The engine can be any ruby xml parser that offers a sax or streaming parsing scheme
# that sends callbacks to a handler object for the various node events encountered in the xml stream.
# The currently supported parsers are the Ruby librarys libxml-ruby, nokogiri, ox, and rexml.
#
# Without a configuration template, this parser will return a generic tree of hashes and arrays,
# representing the xml structure and data that was fed into the parser. With a configuration template,
# this parser can create resulting objects and trees that are custom transformations of the input xml.
#
# The goal in writing this parser was to build custom objects from xml, in a single pass,
# without having to build a generic tree first and then pick it apart with ugly code scattered all over
# our projects' classes.
#
# The primaray use case that motivated this parser's construction was converting Filemaker Server's
# xml response documents into Ruby result-set arrays containing record hashes. A primary example of
# this use can be seen in the Ruby gem 'ginjo-rfm' (a Ruby-Filemaker adapter).
#  
#
# Useage:
#   irb -rubygems -I./  -r  lib/rfm/utilities/sax_parser.rb
#   SaxParser.parse(io, template=nil, initial_object=nil, parser=nil, options={})
#     io: xml-string or io object
#      template: file-name, yaml, xml, symbol, or hash
#      initial_object: the parent object - any object to which the resulting build will be attached to.
#     parser: backend parser symbol or custom backend handler instance
#     options: extra options
#   
#
# Note: 'attach: cursor' puts the object in the cursor & stack but does not attach it to the parent.
#       'attach: none' prevents the object from entering the cursor or stack.
#        Both of these will still allow processing of attributes and child elements.
#
# Note: Attribute attachment is controlled first by the attributes' model's :attributes hash (controls individual attrs),
#       and second by the base model's main hash. Any model's main hash :attach_attributes only controls
#       attributes that will be attached to that model's object. So if a model's object is not attached to anything
#       (:attach=>'none'), then the higher base-model's :attach_attributes will control the lower model's attribute attachment.
#       Put another way: If a model is :attach=>'none', then its :attach_attributes won't be counted.
#
#   
# Examples:
#   Rfm::SaxParser.parse('some/file.xml')  # => defaults to best xml backend with no parsing configuration.
#   Rfm::SaxParser.parse('some/file.xml', nil, nil, :ox)  # => uses ox backend or throws error.
#   Rfm::SaxParser.parse('some/file.xml', {'compact'=>true}, :rexml)  # => uses inline configuration with rexml parser.
#   Rfm::SaxParser.parse('some/file.xml', 'path/to/config.yml', SomeClass.new)  # => loads config template from yml file and builds on top of instance of SomeClass.
#
#
# ####  CONFIGURATION  #####
#
# YAML structure defining a SAX xml parsing template.
# An element may contain these config directives.
# An attribute may contain some of these config directives.
# Options:
#   initialize_with:  OBSOLETE?  string, symbol, or array (object, method, params...). Should return new object. See Rfm::SaxParser::Cursor#get_callback.
#   elements:                    array of element hashes [{'name'=>'element-tag'},...]
#   attributes:                  array of attribute hashes {'name'=>'attribute-name'} UC
#   class:                      string-or-class: class name for new element
#    attach:                      string: shared, _shared_var_name, private, hash, array, cursor, none - how to attach this element or attribute to #object. 
#                                array: [0]string of above, [1..-1]new_element_callback options (see get_callback method).
#    attach_elements:            string: same as 'attach' - how to attach ANY subelements to this model's object, unless they have their own 'attach' specification.
#    attach_attributes:          string: same as 'attach' - how to attach ANY attributes to this model's object, unless they have their own 'attach' specification.
#   before_close:                string, symbol, or array (object, method, params...). See Rfm::SaxParser::Cursor#get_callback.
#   as_name:                    string: store element or attribute keyed as specified
#   delimiter:                  string: attribute/hash key to delineate objects with identical tags
#    create_accessors:           string or array: all, private, shared, hash, none
#    accessor:                   string: all, private, shared, hash, none
#    element_handler:  NOT-USED?  string, symbol, or array (object, method, params...). Should return new object. See Rfm::SaxParser::Cursor#get_callback.
#                               Default attach prefs are 'cursor'.
#                                Use this when all new-element operations should be offloaded to custom class or module.
#                                Should return an instance of new object.
#   translate: UC               Consider adding a 'translate' option to point to a method on the current model's object to use to translate values for attributes.
#
#   compact?
#
# ####  See below for notes & todos  ####


require 'yaml'
require 'forwardable'
require 'stringio'

module Rfm
  class SaxParser
  
    extend Forwardable
    
    def_delegator :'Rfm::SaxParser::Handler', :build
    def_delegator :'Rfm::SaxParser::Handler', :build, :parse
    def_delegator :'Rfm::SaxParser::Handler', :build, :call

    RUBY_VERSION_NUM = RUBY_VERSION[0,3].to_f

    PARSERS = {}

    # These defaults can be set here or in any ancestor/enclosing module or class,
    # as long as the defaults or their constants can be seen from this POV.
    #
    #  Default class MUST be a descendant of Hash or respond to hash methods !!!
    #   
    # For backend, use :libxml, :nokogiri, :ox, :rexml, or anything else, if you want it to always default
    # to something other than the fastest backend found.
    # Using nil will let the SaxParser decide.
    @parser_defaults = {
      :default_class => Hash,
      :backend => nil,
      :text_label => 'text',
      :tag_translation => lambda {|txt| txt.gsub(/\-/, '_').downcase},
      :shared_variable_name => 'attributes',
      :templates => {},
      :template_prefix => nil
    }

    # Merge any upper-level default definitions
    if defined? PARSER_DEFAULTS
      tmp_defaults = PARSER_DEFAULTS.dup
      PARSER_DEFAULTS.replace(@parser_defaults).merge!(tmp_defaults)
    else
      PARSER_DEFAULTS = @parser_defaults
    end

    # Convert defaults to constants, available to all sub classes/modules/instances.
    PARSER_DEFAULTS.each do |k, v|
      k = k.to_s.upcase
      #(const_set k, v) unless eval("defined? #{k}")   #(const_defined?(k) or defined?(k))
      if eval("defined? #{k}")
        (const_set k, eval(k))
      else
        (const_set k, v)
      end
    end

    ::Object::ATTACH_OBJECT_DEFAULT_OPTIONS = {
      :shared_variable_name => SHARED_VARIABLE_NAME,
      :default_class => DEFAULT_CLASS,
      :text_label => TEXT_LABEL,
      :create_accessors => [] #:all, :private, :shared, :hash
    }
    

    # A Cursor instance is created for each element encountered in the parsing run
    # and is where the parsing result is constructed from the custom parsing template.
    # The cursor is the glue between the handler and the resulting object build. The
    # cursor receives input from the handler, loads the corresponding template data,
    # and manipulates the incoming xml data to build the resulting object.
    #
    # Each cursor is added to the stack when its element begins, and removed from
    # the stack when its element ends. The cursor tracks all the important objects
    # necessary to build the resulting object. If you call #cursor on the handler,
    # you will always get the last object added to the stack. Think of a cursor as
    # a framework of tools that accompany each element's build process.
    class Cursor
      extend Forwardable

      # model - currently active model (rename to current_model)
      # local_model - model of this cursor's tag (rename to local_model)
      # newtag - incoming tag of yet-to-be-created cursor. Get rid of this if you can.
      # element_attachment_prefs - local object's attachment prefs based on local_model and current_model.
      # level - cursor depth
      attr_accessor :model, :local_model, :object, :tag, :handler, :parent, :level, :element_attachment_prefs, :new_element_callback, :initial_attributes  #, :newtag


      #SaxParser.install_defaults(self)

      def_delegators :handler, :top, :stack

      # Main get-constant method
      def self.get_constant(klass)
        #puts "Getting constant '#{klass.to_s}'"

        case
        when klass.is_a?(Class); klass
          #when (klass=klass.to_s) == ''; DEFAULT_CLASS
        when klass.nil?; DEFAULT_CLASS
        when klass == ''; DEFAULT_CLASS
        when klass[/::/]; eval(klass)
        when defined?(klass); const_get(klass)  ## == 'constant'; const_get(klass)
          #when defined?(klass); eval(klass) # This was for 'element_handler' pattern.
        else
          Rfm.log.warn "Could not find constant '#{klass}'"
          DEFAULT_CLASS
        end
      end

      def initialize(_tag, _handler, _parent=nil, _initial_attributes=nil) #, caller_binding=nil)
        #def initialize(_model, _obj, _tag, _handler)
        @tag     =  _tag
        @handler = _handler
        @parent = _parent || self
        @initial_attributes = _initial_attributes
        @level = @parent.level.to_i + 1
        @local_model = (model_elements?(@tag, @parent.model) || DEFAULT_CLASS.new)
        @element_attachment_prefs = attachment_prefs(@parent.model, @local_model, 'element')
        #@attribute_attachment_prefs = attachment_prefs(@parent.model, @local_model, 'attribute')

        if @element_attachment_prefs.is_a? Array
          @new_element_callback = @element_attachment_prefs[1..-1]
          @element_attachment_prefs = @element_attachment_prefs[0]
          if @element_attachment_prefs.to_s == 'default'
            @element_attachment_prefs = nil
          end
        end

        #puts ["\nINITIALIZE_CURSOR tag: #{@tag}", "parent.object: #{@parent.object.class}", "local_model: #{@local_model.class}", "el_prefs: #{@element_attachment_prefs}",  "new_el_callback: #{@new_element_callback}", "attributes: #{@initial_attributes}"]

        self
      end


      #####  SAX METHODS  #####

      # Receive a single attribute (any named attribute or text)
      def receive_attribute(name, value)
        #puts ["\nRECEIVE_ATTR '#{name}'", "value: #{value}", "tag: #{@tag}", "object: #{object.class}", "model: #{model['name']}"]
        new_att = {name=>value}    #.new.tap{|att| att[name]=value}
        assign_attributes(new_att) #, @object, @model, @local_model)
      rescue
        Rfm.log.warn "Error: could not assign attribute '#{name.to_s}' to element '#{self.tag.to_s}': #{$!}"
      end

      def receive_start_element(_tag, _attributes)
        #puts ["\nRECEIVE_START '#{_tag}'", "current_object: #{@object.class}", "current_model: #{@model['name']}", "attributes #{_attributes}"]
        new_cursor = Cursor.new(_tag, @handler, self, _attributes) #, binding)
        new_cursor.process_new_element(binding)
        new_cursor
      end # receive_start_element

      # Decides how to attach element & attributes associated with this cursor.
      def process_new_element(caller_binding=binding)
        #puts ["\nPROCESS_NEW_ELEMENT tag: #{@tag}", "@element_attachment_prefs: #{@element_attachment_prefs}", "@local_model: #{local_model}"]

        new_element = @new_element_callback ? get_callback(@new_element_callback, caller_binding) : nil

        case
          # when inital cursor, just set model & object.
        when @tag == '__TOP__';
          #puts "__TOP__"
          @model = @handler.template
          @object = @handler.initial_object

        when @element_attachment_prefs == 'none';
          #puts "__NONE__"
          @model = @parent.model #nil
          @object = @parent.object #nil

          if @initial_attributes && @initial_attributes.any? #&& @attribute_attachment_prefs != 'none'
            assign_attributes(@initial_attributes) #, @object, @model, @local_model) 
          end

        when @element_attachment_prefs == 'cursor';
          #puts "__CURSOR__"
          @model = @local_model
          @object = new_element || DEFAULT_CLASS.allocate

          if @initial_attributes && @initial_attributes.any? #&& @attribute_attachment_prefs != 'none'
            assign_attributes(@initial_attributes) #, @object, @model, @local_model) 
          end

        else
          #puts "__OTHER__"
          @model = @local_model
          @object = new_element || DEFAULT_CLASS.allocate

          if @initial_attributes && @initial_attributes.any? #&& @attribute_attachment_prefs != 'none'
            #puts "PROCESS_NEW_ELEMENT calling assign_attributes with ATTRIBUTES #{@initial_attributes}"
            assign_attributes(@initial_attributes) #, @object, @model, @local_model) 
          end

          # If @local_model has a delimiter, defer attach_new_element until later.
          #puts "PROCESS_NEW_ELEMENT delimiter of @local_model #{delimiter?(@local_model)}"
          if !delimiter?(@local_model) 
            #attach_new_object(@parent.object, @object, @tag, @parent.model, @local_model, 'element')
            #puts "PROCESS_NEW_ELEMENT calling attach_new_element with TAG #{@tag} and OBJECT #{@object}"
            attach_new_element(@tag, @object)
          end      
        end

        self
      end


      def receive_end_element(_tag)
        #puts ["\nRECEIVE_END_ELEMENT '#{_tag}'", "tag: #{@tag}", "object: #{@object.class}", "model: #{@model['name']}", "local_model: #{@local_model['name']}"]
        #puts ["\nEND_ELEMENT_OBJECT", object.to_yaml]
        begin

          if _tag == @tag && (@model == @local_model)
            # Data cleaup
            compactor_settings = compact? || compact?(top.model)
            #(compactor_settings = compact?(top.model)) unless compactor_settings # prefer local settings, or use top settings.
            (clean_members {|v| clean_members(v){|w| clean_members(w)}}) if compactor_settings
          end

          if (delimiter = delimiter?(@local_model); delimiter && !['none','cursor'].include?(@element_attachment_prefs.to_s))
            #attach_new_object(@parent.object, @object, @tag, @parent.model, @local_model, 'element')
            #puts "RECEIVE_END_ELEMENT attaching new element TAG (#{@tag}) OBJECT (#{@object.class}) #{@object.to_yaml} WITH LOCAL MODEL #{@local_model.to_yaml} TO PARENT (#{@parent.object.class}) #{@parent.object.to_yaml} PARENT MODEL #{@parent.model.to_yaml}"
            attach_new_element(@tag, @object)
          end      

          if _tag == @tag #&& (@model == @local_model)
            # End-element callbacks.
            #run_callback(_tag, self)
            callback = before_close?(@local_model)
            get_callback(callback, binding) if callback
          end

          if _tag == @tag
            # return true only if matching tags
            return true
          end

          # # return true only if matching tags
          # if _tag == @tag
          #   return true
          # end

          return
          #           rescue
          #            Rfm.log.debug "Error: end_element tag '#{_tag}' failed: #{$!}"
        end
      end

      ###  Parse callback instructions, compile & send callback method  ###
      ###  TODO: This is way too convoluted. Document it better, or refactor!!!
      # This method will send a method to an object, with parameters, and return a new object.
      # Input (first param): string, symbol, or array of strings
      # Returns: object
      # Default options:
      #   :object=>object
      #   :method=>'a method name string or symbol'
      #   :params=>"params string to be eval'd in context of cursor"
      # Usage:
      #   callback: send a method (or eval string) to an object with parameters, consisting of...
      #     string: a string to be eval'd in context of current object.
      #     or symbol: method to be called on current object.
      #     or array: object, method, params.
      #       object: <object or string>
      #       method: <string or symbol>
      #       params: <string>
      #
      # TODO-MAYBE: Change param order to (method, object, params),
      #             might help confusion with param complexities.
      #
      def get_callback(callback, caller_binding=binding, defaults={})
        input = callback.is_a?(Array) ? callback.dup : callback
        #puts "\nGET_CALLBACK tag: #{tag}, callback: #{callback}"
        params = case
                 when input.is_a?(String) || input.is_a?(Symbol)
                   [nil, input]
                   # when input.is_a?(Symbol)
                   #   [nil, input]
                 when input.is_a?(Array)
                   #puts ["\nCURSOR#get_callback is an array", input]
                   case
                   when input[0].is_a?(Symbol)
                     [nil, input].flatten(1)
                   when input[1].is_a?(String) && ( input.size > 2 || (remove_colon=(input[1][0,1]==":"); remove_colon) )
                     code_or_method = input[1].dup
                     code_or_method[0]='' if remove_colon
                     code_or_method = code_or_method.to_sym
                     output = [input[0], code_or_method, input[2..-1]].flatten(1)
                     #puts ["\nCURSOR#get_callback converted input[1] to symbol", output]
                     output
                   else # when input is ['object', 'sym-or-str', 'param1',' param2', ...]
                     input
                   end
                 else
                   []
                 end

        obj_raw = params.shift
        #puts ["\nOBJECT_RAW:","class: #{obj_raw.class}", "object: #{obj_raw}"]
        obj = if obj_raw.is_a?(String)
                eval(obj_raw.to_s, caller_binding)
              else
                obj_raw
              end
        if obj.nil? || obj == ''
          obj = defaults[:object] || @object
        end
        #puts ["\nOBJECT:","class: #{obj.class}", "object: #{obj}"]

        code = params.shift || defaults[:method]
        params.each_with_index do |str, i|
          if str.is_a?(String)
            params[i] = eval(str, caller_binding)
          end
        end
        params = defaults[:params] if params.size == 0
        #puts ["\nGET_CALLBACK tag: #{@tag}" ,"callback: #{callback}", "obj.class: #{obj.class}", "code: #{code}", "params-class #{params.class}"]
        case
        when (code.nil? || code=='')
          obj
        when (code.is_a?(Symbol) || params)
          #puts ["\nGET_CALLBACK sending symbol", obj.class, code] 
          obj.send(*[code, params].flatten(1).compact)
        when code.is_a?(String)
          #puts ["\nGET_CALLBACK evaling string", obj.class, code]
          obj.send :eval, code
          #eval(code, caller_binding)
        end          
      end

      # # Run before-close callback.
      # def run_callback(_tag, _cursor=self, _model=_cursor.local_model, _object=_cursor.object )
      #   callback = before_close?(_model)
      #   #puts ["\nRUN_CALLBACK", _tag, _cursor.tag, _object.class, callback, callback.class]
      #   if callback.is_a? Symbol
      #     _object.send callback, _cursor
      #   elsif callback.is_a?(String)
      #     _object.send :eval, callback
      #   end
      # end




      #####  MERGE METHODS  #####

      # Assign attributes to element.
      def assign_attributes(_attributes)
        if _attributes && !_attributes.empty?

          _attributes.each do |k,v|
            #attach_new_object(base_object, v, k, base_model, model_attributes?(k, new_model), 'attribute')}
            attr_model = model_attributes?(k, @local_model)

            label = label_or_tag(k, attr_model)

            prefs = [attachment_prefs(@model, attr_model, 'attribute')].flatten(1)[0]

            shared_var_name = shared_variable_name(prefs)
            (prefs = "shared") if shared_var_name

            # Use local create_accessors prefs first, then more general ones.
            create_accessors = accessor?(attr_model) || create_accessors?(@model)
            #(create_accessors = create_accessors?(@model)) unless create_accessors && create_accessors.any?

            #puts ["\nATTACH_NEW_OBJECT 1", "type: #{type}", "label: #{label}", "base_object: #{base_object.class}", "new_object: #{new_object.class}", "delimiter: #{delimiter?(new_model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]
            @object._attach_object!(v, label, delimiter?(attr_model), prefs, 'attribute', :default_class=>DEFAULT_CLASS, :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
          end

        end
      end

      #   def attach_new_object(base_object, new_object, name, base_model, new_model, type)
      #     label = label_or_tag(name, new_model)
      #     
      #     # Was this, which works fine, but not as efficient:
      #     # prefs = [attachment_prefs(base_model, new_model, type)].flatten(1)[0]
      #     prefs = if type=='attribute'
      #       [attachment_prefs(base_model, new_model, type)].flatten(1)[0]
      #     else
      #       @element_attachment_prefs
      #     end
      #     
      #     shared_var_name = shared_variable_name(prefs)
      #     (prefs = "shared") if shared_var_name
      #     
      #     # Use local create_accessors prefs first, then more general ones.
      #     create_accessors = accessor?(new_model)
      #     (create_accessors = create_accessors?(base_model)) unless create_accessors && create_accessors.any?
      #     
      #     # # This is NEW!
      #     # translator = new_model['translator']
      #     # if translator
      #     #   new_object = base_object.send translator, name, new_object
      #     # end
      #     
      #     
      #     #puts ["\nATTACH_NEW_OBJECT 1", "type: #{type}", "label: #{label}", "base_object: #{base_object.class}", "new_object: #{new_object.class}", "delimiter: #{delimiter?(new_model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]
      #     base_object._attach_object!(new_object, label, delimiter?(new_model), prefs, type, :default_class=>DEFAULT_CLASS, :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
      #     #puts ["\nATTACH_NEW_OBJECT 2: #{base_object.class} with ", label, delimiter?(new_model), prefs, type, :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors]
      #     # if type == 'attribute'
      #     #   puts ["\nATTACH_ATTR", "name: #{name}", "label: #{label}", "new_object: #{new_object.class rescue ''}", "base_object: #{base_object.class rescue ''}", "base_model: #{base_model['name'] rescue ''}", "new_model: #{new_model['name'] rescue ''}", "prefs: #{prefs}"]
      #     # end
      #   end

      def attach_new_element(name, new_object)   #old params (base_object, new_object, name, base_model, new_model, type)
        label = label_or_tag(name, @local_model)

        # Was this, which works fine, but not as efficient:
        # prefs = [attachment_prefs(base_model, new_model, type)].flatten(1)[0]
        prefs = @element_attachment_prefs

        shared_var_name = shared_variable_name(prefs)
        (prefs = "shared") if shared_var_name

        # Use local create_accessors prefs first, then more general ones.
        create_accessors = accessor?(@local_model) || create_accessors?(@parent.model)
        #(create_accessors = create_accessors?(@parent.model)) unless create_accessors && create_accessors.any?

        # # This is NEW!
        # translator = new_model['translator']
        # if translator
        #   new_object = base_object.send translator, name, new_object
        # end


        #puts ["\nATTACH_NEW_ELEMENT 1", "new_object: #{new_object}", "parent_object: #{@parent.object}", "label: #{label}", "delimiter: #{delimiter?(@local_model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]
        @parent.object._attach_object!(new_object, label, delimiter?(@local_model), prefs, 'element', :default_class=>DEFAULT_CLASS, :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
        # if type == 'attribute'
        #   puts ["\nATTACH_ATTR", "name: #{name}", "label: #{label}", "new_object: #{new_object.class rescue ''}", "base_object: #{base_object.class rescue ''}", "base_model: #{base_model['name'] rescue ''}", "new_model: #{new_model['name'] rescue ''}", "prefs: #{prefs}"]
        # end
      end

      def attachment_prefs(base_model, new_model, type)
        case type
        when 'element'; attach?(new_model) || attach_elements?(base_model) #|| attach?(top.model) || attach_elements?(top.model)
        when 'attribute'; attach?(new_model) || attach_attributes?(base_model) #|| attach?(top.model) || attach_attributes?(top.model)
        end
      end

      def shared_variable_name(prefs)
        rslt = nil
        if prefs.to_s[0,1] == "_"
          rslt = prefs.to_s[1..-1] #prefs.gsub(/^_/, '')
        end
      end


      #####  UTILITY  #####

      def get_constant(klass)
        self.class.get_constant(klass)
      end

      # Methods for current _model
      def ivg(name, _object=@object); _object.instance_variable_get "@#{name}"; end
      def ivs(name, value, _object=@object); _object.instance_variable_set "@#{name}", value; end
      def model_elements?(which=nil, _model=@model); _model && _model.has_key?('elements') && ((_model['elements'] && which) ? _model['elements'].find{|e| e['name']==which} : _model['elements']) ; end
      def model_attributes?(which=nil, _model=@model); _model && _model.has_key?('attributes') && ((_model['attributes'] && which) ? _model['attributes'].find{|a| a['name']==which} : _model['attributes']) ; end
      def depth?(_model=@model); _model && _model['depth']; end
      def before_close?(_model=@model); _model && _model['before_close']; end
      def each_before_close?(_model=@model); _model && _model['each_before_close']; end
      def compact?(_model=@model); _model && _model['compact']; end
      def attach?(_model=@model); _model && _model['attach']; end
      def attach_elements?(_model=@model); _model && _model['attach_elements']; end
      def attach_attributes?(_model=@model); _model && _model['attach_attributes']; end
      def delimiter?(_model=@model); _model && _model['delimiter']; end
      def as_name?(_model=@model); _model && _model['as_name']; end
      def initialize_with?(_model=@model); _model && _model['initialize_with']; end
      def create_accessors?(_model=@model); _model && _model['create_accessors'] && [_model['create_accessors']].flatten.compact; end
      def accessor?(_model=@model); _model && _model['accessor'] && [_model['accessor']].flatten.compact; end
      def element_handler?(_model=@model); _model && _model['element_handler']; end


      # Methods for submodel

      # This might be broken.
      def label_or_tag(_tag=@tag, new_model=@local_model); as_name?(new_model) || _tag; end


      def clean_members(obj=@object)
        #puts ["CURSOR.clean_members: #{object.class}", "tag: #{tag}", "model-name: #{model[:name]}"]
        #   cursor.object = clean_member(cursor.object)
        #   clean_members(ivg(shared_attribute_var, obj))
        if obj.is_a?(Hash)
          obj.dup.each do |k,v|
            obj[k] = clean_member(v)
            yield(v) if block_given?
          end
        elsif obj.is_a?(Array)
          obj.dup.each_with_index do |v,i|
            obj[i] = clean_member(v)
            yield(v) if block_given?
          end
        else  
          obj.instance_variables.each do |var|
            dat = obj.instance_variable_get(var)
            obj.instance_variable_set(var, clean_member(dat))
            yield(dat) if block_given?
          end
        end
        #   obj.instance_variables.each do |var|
        #     dat = obj.instance_variable_get(var)
        #     obj.instance_variable_set(var, clean_member(dat))
        #     yield(dat) if block_given?
        #   end
      end

      def clean_member(val)
        if val.is_a?(Hash) || val.is_a?(Array); 
          if val && val.empty?
            nil
          elsif val && val.respond_to?(:values) && val.size == 1
            val.values[0]
          else
            val
          end
        else
          val
          #   # Probably shouldn't do this on instance-var values. ...Why not?
          #     if val.instance_variables.size < 1
          #       nil
          #     elsif val.instance_variables.size == 1
          #       val.instance_variable_get(val.instance_variables[0])
          #     else
          #       val
          #     end
        end
      end

    end # Cursor



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

      #SaxParser.install_defaults(self)


      ###  Class Methods  ###

      # Main parsing interface (also aliased at SaxParser.parse)
      # options: template:nil, initial_object:nil, parser:nil, ... 
      def self.build(io='', **options) #template=nil, initial_object=nil, parser=nil, options={})
        #puts "Handler.build options: #{options}"
        parser_backend = options[:parser_backend] || BACKEND
        template = options[:template]
        initial_object = options[:initial_object]
        handler_class = get_backend(parser_backend)
        (Rfm.log.info "Using backend parser: #{handler_class}, with template: #{template}") if options[:log_parser]
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
      end # self.included

      # Takes backend symbol and returns custom Handler class for specified backend.
      def self.get_backend(parser_backend=BACKEND)
        (parser_backend = decide_backend) unless parser_backend
        if parser_backend.is_a?(String) || parser_backend.is_a?(Symbol)
          parser_proc = PARSERS[parser_backend.to_sym][:proc]
          parser_proc.call unless parser_proc.nil? || const_defined?((parser_backend.to_s.capitalize + 'Handler').to_sym)
          SaxParser.const_get(parser_backend.to_s.capitalize + "Handler")
        end
      rescue
        raise "Could not load the backend parser '#{parser}': #{$!}"
      end

      # Finds a loadable backend and returns its symbol.
      def self.decide_backend
        #BACKENDS.find{|b| !Gem::Specification::find_all_by_name(b[1]).empty? || b[0]==:rexml}[0]
        PARSERS.find{|k,v| !Gem::Specification::find_all_by_name(v[:file]).empty? || k == :rexml}[0]
      rescue
        raise "The xml parser could not find a loadable backend library: #{$!}"
      end



      ###  Instance Methods  ###

      def initialize(_template=nil, _initial_object=nil, **options)
        @initial_object = case
                          when _initial_object.nil?; DEFAULT_CLASS.new
                          when _initial_object.is_a?(Class); _initial_object.new
                          when _initial_object.is_a?(String) || _initial_object.is_a?(Symbol); SaxParser.get_constant(_initial_object).new
                          else _initial_object
                          end
        @stack = []
        @stack_debug=[]
        @template_prefix = options[:template_prefix] || defined?(TEMPLATE_PREFIX) && TEMPLATE_PREFIX || ''
        @template = get_template(_template)
        set_cursor Cursor.new('__TOP__', self).process_new_element
      end

      # Takes string, symbol, hash, and returns a (possibly cached) parsing template.
      # String can be a file name, yaml, xml.
      # Symbol is a name of a template stored in SaxParser@templates (you would set the templates when your app or gem loads).
      # Templates stored in the SaxParser@templates var can be strings of code, file specs, or hashes.
      def get_template(name)
        #   dat = templates[name]
        #   if dat
        #     rslt = load_template(dat)
        #   else
        #     rslt = load_template(name)
        #   end
        #   (templates[name] = rslt) #unless dat == rslt
        # The above works, but this is cleaner.
        TEMPLATES[name] = TEMPLATES[name] && load_template(TEMPLATES[name]) || load_template(name)
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
               else DEFAULT_CLASS.new
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
        return name unless TAG_TRANSLATION.is_a?(Proc)
        TAG_TRANSLATION.call(name.to_s)
      end

      # Add a node to an existing element.
      def _start_element(tag, attributes=nil, *args)
        #puts ["_START_ELEMENT", tag, attributes, args].to_yaml # if tag.to_s.downcase=='fmrestulset'
        tag = transform tag
        if attributes
          # This crazy thing transforms attribute keys to underscore (or whatever).
          #attributes = default_class[*attributes.collect{|k,v| [transform(k),v] }.flatten]
          # This works but downcases all attribute names - not good.
          attributes = DEFAULT_CLASS.new.tap {|hash| attributes.each {|k, v| hash[transform(k)] = v}}
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
        cursor.receive_attribute(TEXT_LABEL, value)
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



    #####  SAX PARSER BACKEND HANDLERS  #####

    PARSERS[:libxml] = {:file=>'libxml-ruby', :proc => proc do
      require 'libxml'
      class LibxmlHandler
        include LibXML
        include XML::SaxParser::Callbacks
        include Handler

        def run_parser(io)
          # parser = case
          #   when (io.is_a?(File) || io.is_a?(StringIO))
          #    XML::SaxParser.io(io)
          #   when io[/^</]
          #    XML::SaxParser.io(StringIO.new(io))
          #   else
          #    XML::SaxParser.io(File.new(io))
          # end
          parser = SaxParser.io(io)
          parser.callbacks = self
          parser.parse
        end

        alias_method :on_start_element, :_start_element
        alias_method :on_end_element, :_end_element
        alias_method :on_characters, :_text
        alias_method :on_internal_subset, :_doctype
      end # LibxmlSax  
    end}

    PARSERS[:nokogiri] = {:file=>'nokogiri', :proc => proc do
      require 'nokogiri'
      class NokogiriHandler < Nokogiri::XML::SAX::Document
        include Handler

        def run_parser(io)
          parser = Nokogiri::XML::SAX::Parser.new(self)
          # parser.parse case
          #   when (io.is_a?(File) || io.is_a?(StringIO))
          #    io
          #   when io[/^</]
          #    StringIO.new(io)
          #   else
          #    File.new(io)
          # end
          parser.parse(io)
        end

        alias_method :start_element, :_start_element
        alias_method :end_element, :_end_element
        alias_method :characters, :_text
      end # NokogiriSax
    end}

    PARSERS[:ox] = {:file=>'ox', :proc => proc do
      require 'ox'
      class OxHandler < ::Ox::Sax
        include Handler

        def run_parser(io)
          options={:convert_special=>true}
          # case
          # when (io.is_a?(File) || io.is_a?(StringIO)); Ox.sax_parse self, io, options
          # when io.to_s[/^</]; StringIO.open(io){|f| Ox.sax_parse self, f, options}
          # else File.open(io){|f| Ox.sax_parse self, f, options}
          # end
          Ox.sax_parse self, io, options
        end

        alias_method :start_element, :_start_element
        alias_method :end_element, :_end_element
        alias_method :attr, :_attribute
        alias_method :text, :_text    
        alias_method :doctype, :_doctype  
      end # OxFmpSax
    end}

    PARSERS[:rexml] = {:file=>'rexml/document', :proc => proc do
      require 'rexml/document'
      require 'rexml/streamlistener'
      class RexmlHandler
        include REXML::StreamListener
        include Handler

        def run_parser(io)
          parser = REXML::Document
          #puts "#{self.class.name}#run_parser io object is a: #{io.class.ancestors}"
          parser.parse_stream(io, self)
        end

        alias_method :tag_start, :_start_element
        alias_method :tag_end, :_end_element
        alias_method :text, :_text
        alias_method :doctype, :_doctype
      end # RexmlStream
    end}

  end # SaxParser
end # Rfm




#####  CORE ADDITIONS  #####

class Object

  # Master method to attach any object to this object.
  def _attach_object!(obj, *args) # name/label, collision-delimiter, attachment-prefs, type, *options: <options>
    #puts ["\nATTACH_OBJECT._attach_object", "self.class: #{self.class}", "obj.class: #{obj.class}", "obj.to_s: #{obj.to_s}", "args: #{args}"]
    options = ATTACH_OBJECT_DEFAULT_OPTIONS.merge(args.last.is_a?(Hash) ? args.pop : {}){|key, old, new| new || old}
    #   name = (args[0] || options[:name])
    #   delimiter = (args[1] || options[:delimiter])
    prefs = (args[2] || options[:prefs])
    #   type = (args[3] || options[:type])
    return if (prefs=='none' || prefs=='cursor')   #['none', 'cursor'].include? prefs ... not sure which is faster.
    self._merge_object!(
      obj,
      args[0] || options[:name] || 'unknown_name',
      args[1] || options[:delimiter],
      prefs,
      args[3] || options[:type],
      options
    )

    #     case
    #     when prefs=='none' || prefs=='cursor'; nil
    #     when name
    #       self._merge_object!(obj, name, delimiter, prefs, type, options)
    #     else
    #       self._merge_object!(obj, 'unknown_name', delimiter, prefs, type, options)
    #     end
    #puts ["\nATTACH_OBJECT RESULT", self.to_yaml]
    #puts ["\nATTACH_OBJECT RESULT PORTALS", (self.portals.to_yaml rescue 'no portals')]
  end

  # Master method to merge any object with this object
  def _merge_object!(obj, name, delimiter, prefs, type, options={})
    #puts ["\n-----OBJECT._merge_object", self.class, (obj.to_s rescue obj.class), name, delimiter, prefs, type.capitalize, options].join(', ')
    if prefs=='private'
      _merge_instance!(obj, name, delimiter, prefs, type, options)
    else
      _merge_shared!(obj, name, delimiter, prefs, type, options)
    end
  end

  # Merge a named object with the shared instance variable of self.
  def _merge_shared!(obj, name, delimiter, prefs, type, options={})
    shared_var = instance_variable_get("@#{options[:shared_variable_name]}") || instance_variable_set("@#{options[:shared_variable_name]}", options[:default_class].new)
    #puts "\n-----OBJECT._merge_shared: self '#{self.class}' obj '#{obj.class}' name '#{name}' delimiter '#{delimiter}' type '#{type}' shared_var '#{options[:shared_variable_name]} - #{shared_var.class}'"
    # TODO: Figure this part out:
    # The resetting of shared_variable_name to 'attributes' was to fix Asset.field_controls (it was not able to find the valuelive name).
    # I think there might be a level of hierarchy that is without a proper cursor model, when using shared variables & object delimiters.
    shared_var._merge_object!(obj, name, delimiter, nil, type, options.merge(:shared_variable_name=>ATTACH_OBJECT_DEFAULT_OPTIONS[:shared_variable_name]))
  end

  # Merge a named object with the specified instance variable of self.
  def _merge_instance!(obj, name, delimiter, prefs, type, options={})
    #puts ["\nOBJECT._merge_instance!", "self.class: #{self.class}", "obj.class: #{obj.class}", "name: #{name}", "delimiter: #{delimiter}", "prefs: #{prefs}", "type: #{type}", "options.keys: #{options.keys}", '_end_merge_instance!']  #.join(', ')
    rslt = if instance_variable_get("@#{name}") || delimiter
             if delimiter
               delimit_name = obj._get_attribute(delimiter, options[:shared_variable_name]).to_s.downcase
               #puts ["\n_setting_with_delimiter", delimit_name]
               #instance_variable_set("@#{name}", instance_variable_get("@#{name}") || options[:default_class].new)[delimit_name]=obj
               # This line is more efficient than the above line.
               instance_variable_set("@#{name}", options[:default_class].new) unless instance_variable_get("@#{name}")

               # This line was active in 3.0.9.pre01, but it was inserting each portal array as an element in the array,
               # after all the Rfm::Record instances had been added. This was causing an potential infinite recursion situation.
               # I don't think this line was supposed to be here - was probably an older piece of code.
               #instance_variable_get("@#{name}")[delimit_name]=obj

               #instance_variable_get("@#{name}")._merge_object!(obj, delimit_name, nil, nil, nil)
               # Trying to handle multiple portals with same table-occurance on same layout.
               # In parsing terms, this is trying to handle multiple elements who's delimiter field contains the SAME delimiter data.
               instance_variable_get("@#{name}")._merge_delimited_object!(obj, delimit_name)
             else
               #puts ["\_setting_existing_instance_var", name]
               if name == options[:text_label]
                 instance_variable_get("@#{name}") << obj.to_s
               else
                 instance_variable_set("@#{name}", [instance_variable_get("@#{name}")].flatten << obj)
               end
             end
           else
             #puts ["\n_setting_new_instance_var", name]
             instance_variable_set("@#{name}", obj)
           end

    # NEW
    _create_accessor(name) if (options[:create_accessors] & ['all','private']).any?

    rslt
  end

  def _merge_delimited_object!(obj, delimit_name)
    #puts "MERGING DELIMITED OBJECT self #{self.class} obj #{obj.class} delimit_name #{delimit_name}"

    case
    when self[delimit_name].nil?; self[delimit_name] = obj
    when self[delimit_name].is_a?(Hash); self[delimit_name].merge!(obj)
    when self[delimit_name].is_a?(Array); self[delimit_name] << obj
    else self[delimit_name] = [self[delimit_name], obj]
    end
  end

  # Get an instance variable, a member of a shared instance variable, or a hash value of self.
  def _get_attribute(name, shared_var_name=nil, options={})
    return unless name
    #puts ["\n\n", self.to_yaml]
    #puts ["OBJECT_get_attribute", self.class, self.instance_variables, name, shared_var_name, options].join(', ')
    (shared_var_name = options[:shared_variable_name]) unless shared_var_name

    rslt = case
           when self.is_a?(Hash) && self[name]; self[name]
           when ((var= instance_variable_get("@#{shared_var_name}")) && var[name]); var[name]
           else instance_variable_get("@#{name}")
           end

    #puts "OBJECT#_get_attribute: name '#{name}' shared_var_name '#{shared_var_name}' options '#{options}' rslt '#{rslt}'"
    rslt
  end

  #   # We don't know which attributes are shared, so this isn't really accurate per the options.
  #   # But this could be useful for mass-attachment of a set of attributes (to increase performance in some situations).
  #   def _create_accessors options=[]
  #     options=[options].flatten.compact
  #     #puts ['CREATE_ACCESSORS', self.class, options, ""]
  #     return false if (options & ['none']).any?
  #     if (options & ['all', 'private']).any?
  #       meta = (class << self; self; end)
  #       meta.send(:attr_reader, *instance_variables.collect{|v| v.to_s[1,99].to_sym})
  #     end
  #     if (options & ['all', 'shared']).any?
  #       instance_variables.collect{|v| instance_variable_get(v)._create_accessors('hash')}
  #     end
  #     return true
  #   end

  # NEW
  def _create_accessor(name)
    #puts "OBJECT._create_accessor '#{name}' for Object '#{self.class}'"
    meta = (class << self; self; end)
    meta.send(:attr_reader, name.to_sym)
  end

  # Attach hash as individual instance variables to self.
  # This is for manually attaching a hash of attributes to the current object.
  # Pass in translation procs to alter the keys or values.
  def _attach_as_instance_variables(hash, options={})
    #hash.each{|k,v| instance_variable_set("@#{k}", v)} if hash.is_a? Hash
    key_translator = options[:key_translator]
    value_translator = options[:value_translator]
    #puts ["ATTACH_AS_INSTANCE_VARIABLES", key_translator, value_translator].join(', ')
    if hash.is_a? Hash
      hash.each do |k,v|
        (k = key_translator.call(k)) if key_translator
        (v = value_translator.call(k, v)) if value_translator
        instance_variable_set("@#{k}", v)
      end
    end
  end

end # Object

class Array
  def _merge_object!(obj, name, delimiter, prefs, type, options={})
    #puts ["\n+++++ARRAY._merge_object", self.class, (obj.to_s rescue obj.class), name, delimiter, prefs, type, options].join(', ')
    case
    when prefs=='shared' || type == 'attribute' && prefs.to_s != 'private' ; _merge_shared!(obj, name, delimiter, prefs, type, options)
    when prefs=='private'; _merge_instance!(obj, name, delimiter, prefs, type, options)
    else self << obj
    end
  end
end # Array

class Hash

  def _merge_object!(obj, name, delimiter, prefs, type, options={})
    #puts ["\n*****HASH._merge_object", "type: #{type}", "name: #{name}", "self.class: #{self.class}", "new_obj: #{(obj.to_s rescue obj.class)}", "delimiter: #{delimiter}", "prefs: #{prefs}", "options: #{options}"]
    output = case
             when prefs=='shared'
               _merge_shared!(obj, name, delimiter, prefs, type, options)
             when prefs=='private'
               _merge_instance!(obj, name, delimiter, prefs, type, options)
             when (self[name] || delimiter)
               rslt = if delimiter
                        delimit_name =  obj._get_attribute(delimiter, options[:shared_variable_name]).to_s.downcase
                        #puts "MERGING delimited object with hash: self '#{self.class}' obj '#{obj.class}' name '#{name}' delim '#{delimiter}' delim_name '#{delimit_name}' options '#{options}'"
                        self[name] ||= options[:default_class].new

                        #self[name][delimit_name]=obj
                        # This is supposed to handle multiple elements who's delimiter value is the SAME.
                        self[name]._merge_delimited_object!(obj, delimit_name)
                      else
                        if name == options[:text_label]
                          self[name] << obj.to_s
                        else
                          self[name] = [self[name]].flatten
                          self[name] << obj
                        end
                      end
               _create_accessor(name) if (options[:create_accessors].to_a & ['all','shared','hash']).any?

               rslt
             else
               rslt = self[name] = obj
               _create_accessor(name) if (options[:create_accessors] & ['all','shared','hash']).any?
               rslt
             end
    #puts ["\n*****HASH._merge_object! RESULT", self.to_yaml]
    #puts ["\n*****HASH._merge_object! RESULT PORTALS", (self.portals.to_yaml rescue 'no portals')]
    output
  end

  #   def _create_accessors options=[]
  #     #puts ['CREATE_ACCESSORS_for_HASH', self.class, options]
  #     options=[options].flatten.compact
  #     super and
  #     if (options & ['all', 'hash']).any?
  #       meta = (class << self; self; end)
  #       keys.each do |k|
  #         meta.send(:define_method, k) do
  #           self[k]
  #         end
  #       end
  #     end
  #   end

  def _create_accessor(name)
    #puts "HASH._create_accessor '#{name}' for Hash '#{self.class}'"
    meta = (class << self; self; end)
    meta.send(:define_method, name) do
      self[name]
    end
  end

end # Hash




# ####  NOTES and TODOs  ####
#
# done: Move test data & user models to spec folder and local_testing.
# done: Create special file in local_testing for experimentation & testing - will have user models, grammar-yml, calling methods.
# done: Add option to 'compact' unnecessary or empty elements/attributes - maybe - should this should be handled at Model level?
# na  : Separate all attribute options in yml into 'attributes:' hash, similar to 'elements:' hash.
# done: Handle multiple 'text' callbacks for a single element.
# done: Add options for text handling (what to name, where to put).
# done: Fill in other configuration options in yml
# done: Clean_elements doesn't work if elements are non-hash/array objects. Make clean_elements work with object attributes.
# TODO: Clean_elements may not work for non-hash/array objecs with multiple instance-variables.
# na  : Clean_elements may no longer work with a globally defined 'compact'.
# TODO: Do we really need Cursor#top and Cursor#stack ? Can't we get both from handler.stack. Should we store handler in cursor inst var @handler?
# TODO: When using a non-hash/array object as the initial object, things get kinda srambled.
#       See Rfm::Connection, when sending self (the connection object) as the initial_object.
# done: 'compact' breaks badly with fmpxmllayout data.
# na  : Do the same thing with 'ignore' as you did with 'attach', so you can enable using the 'attributes' array of the yml model.
# done: Double-check that you're pointing to the correct model/submodel, since you changed all helper-methods to look at curent-model by default.
# done: Make sure all method calls are passing the model given by the calling-method.
# abrt: Give most of the config options a global possibility. (no true global config, but top-level acts as global for all immediate submodels).
# na  : Block attachment methods from seeing parent if parent isn't the current objects true parent (how?).
# done: Handle attach: hash better (it's not specifically handled, but declaring it will block a parents influence).
# done: CaseInsensitiveHash/IndifferentAccess is not working for sax parser.
# na  : Give the yml (and xml) doc the ability to have a top-level hash like "fmresultset" or "fmresultset_yml" or "fmresultset_xml",
#       then you have a label to refer to it if you load several config docs at once (like into a Rfm::SaxParser::TEMPLATES constant).
#       Use an array of accepted model-keys  to filter whether loaded template is a named-model or actual model data.
# done: Load up all template docs when Rfm loads, or when Rfm::SaxParser loads. For RFM only, not for parser module.
# done: Move SaxParser::Handler class methods to SaxParser, so you can do Rfm::SaxParser.parse(io, backend, template, initial_object)
# done: Switch args order in .build methods to (io, template, initial_object, backend)
# done: Change "grammar" to "template" in all code
# done: Change 'cursor._' methods to something more readable, since they will be used in Rfm and possibly user models.
# done: Split off template loading into load_templates and/or get_templates methods.
# TODO: Something is downcasing somewhere - see the fmpxmllayout response. Looks like 'compact' might have something to do with it.
# done: Make attribute attachment default to individual.
# done: 'attach: shared' doesnt work yet for elements.
# na  : Arrays should always get elements attached to their records and attributes attached to their instance variables. 
# done: Merge 'ignore: self, elements, attributes' config into 'attach: ignore, attach_elements: ignore, attach_attributes: ignore'.
# done: Consider having one single group of methods to attach all objects (elements OR attributes OR text) to any given parent object.
# na  : May need to store 'ignored' models in new cursor, with the parent object instead of the new object. Probably not a good idea
# done: Fix label_or_tag for object-attachment.
# done: Fix delineate_with_hash in parsing of resultset field_meta (should be hash of hashes, not array of hashes).
# done: Test new parser with raw data from multiple sources, make sure it works as raw.
# done: Make sure single-attribute (or text) handler has correct objects & models to work with.
# na  : Rewrite attach_to_what? logic to start with base_object type, then have sub-case statements for the rest.
# done: Build backend-gem loading scheme. Eliminate gem 'require'. Use catch/throw like in XmlParser.
# done: Splash_sax.rb is throwing error when loading User.all when SaxParser.backend is anything other than :ox.
#       This is probably related to the issue of incomming attributes (that are after the incoming start_element) not knowing their model.
#       Some multiple-text attributes were tripping up delineate_with_hash, so I added some fault-tollerance to that method.
#       But those multi-text attributes are still way ugly when passed by libxml or nokogiri. Ox & Rexml are fine and pass them as one chunk.
#       Consider buffering all attributes & text until start of new element.
# YAY :  I bufffered all attributes & text, and the problem is solved.
# na  : Can't configure an attribute (in template) if it is used in delineate_with_hash. (actually it works if you specifiy the as_name: correctly).
# TODO: Some configurations in template cause errors - usually having to do with nil. See below about eliminating all 'rescue's .
# done: Can't supply custom class if it's a String (but an unspecified subclass of plain Object works fine!?).
# TODO: Attaching non-hash/array object to Array will thro error. Is this actually fixed?
# done?: Sending elements with subelements to Shared results in no data attached to the shared var.
# TODO: compact is not working for fmpxmllayout-error. Consider rewrite of 'compact' method, or allow compact to work on end_element with no matching tag.
# mabe: Add ability to put a regex in the as_name parameter, that will operate on the tag/label/name.
# TODO: Optimize:
#        Use variables, not methods.
#        Use string interpolation not concatenation.
#        Use destructive! operations (carefully). Really?
#        Get this book: http://my.safaribooksonline.com/9780321540034?portal=oreilly
#        See this page: http://www.igvita.com/2008/07/08/6-optimization-tips-for-ruby-mri/
# done: Consider making default attribute-attachment shared, instead of instance.
# done: Find a way to get SaxParser defaults into core class patches.
# done: Check resultset portal_meta in Splash Asset model for field-definitions coming out correct according to sax template.
# done: Make sure Rfm::Metadata::Field is being used in portal-definitions.
# done: Scan thru Rfm classes and use @instance variables instead of their accessors, so sax-parser does less work.
# done: Change 'instance' option to 'private'. Change 'shared' to <whatever>.
# done: Since unattached elements won't callback, add their callback to an array of procs on the current cursor at the beginning
#        of the non-attached tag.
# TODO: Handle check-for-errors in non-resultset loads.
# abrt: Figure out way to get doctype from nokogiri. Tried, may be practically impossible.
# TODO: Clean up sax code so that no 'rescue' is needed - if an error happens it should be a legit error outside of SaxParser.
# TODO: Allow attach:none when using handler.


