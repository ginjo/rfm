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
#   Parser.parse(io, template=nil, initial_object=nil, parser=nil, options={})
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
#   SaxChange::Parser.parse('some/file.xml')  # => defaults to best xml backend with no parsing configuration.
#   SaxChange::Parser.parse('some/file.xml', nil, nil, :ox)  # => uses ox backend or throws error.
#   SaxChange::Parser.parse('some/file.xml', {'compact'=>true}, :rexml)  # => uses inline configuration with rexml parser.
#   SaxChange::Parser.parse('some/file.xml', 'path/to/config.yml', SomeClass.new)  # => loads config template from yml file and builds on top of instance of SomeClass.
#
#
# ####  CONFIGURATION  #####
#
# YAML structure defining a SAX xml parsing template.
# An element may contain these config directives.
# An attribute may contain some of these config directives.
# Options:
#   initialize_with:  OBSOLETE?  string, symbol, or array (object, method, params...). Should return new object. See SaxChange::Parser::Cursor#get_callback.
#   elements:                    array of element hashes [{'name'=>'element-tag'},...]
#   attributes:                  array of attribute hashes {'name'=>'attribute-name'} UC
#   class:                      string-or-class: class name for new element
#    attach:                      string: shared, _shared_var_name, private, hash, array, cursor, none - how to attach this element or attribute to #object. 
#                                array: [0]string of above, [1..-1]new_element_callback options (see get_callback method).
#    attach_elements:            string: same as 'attach' - how to attach ANY subelements to this model's object, unless they have their own 'attach' specification.
#    attach_attributes:          string: same as 'attach' - how to attach ANY attributes to this model's object, unless they have their own 'attach' specification.
#   before_close:                string, symbol, or array (object, method, params...). See SaxChange::Parser::Cursor#get_callback.
#   as_name:                    string: store element or attribute keyed as specified
#   delimiter:                  string: attribute/hash key to delineate objects with identical tags
#    create_accessors:           string or array: all, private, shared, hash, none
#    accessor:                   string: all, private, shared, hash, none
#    element_handler:  NOT-USED?  string, symbol, or array (object, method, params...). Should return new object. See SaxChange::Parser::Cursor#get_callback.
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
require 'logger'
require 'saxchange/config'
# require 'saxchange/cursor'
# require 'saxchange/handler'
# require 'saxchange/handler/handlers'

module SaxChange

  class Parser
    using Refinements
  
    attr_accessor :templates
  
    extend Forwardable
    prepend Config
    
    # def_delegator :'SaxChange::Handler', :build
    # def_delegator :'SaxChange::Handler', :build, :parse
    # def_delegator :'SaxChange::Handler', :build, :call

    ::Object::ATTACH_OBJECT_DEFAULT_OPTIONS = {
      :shared_variable_name => Config.defaults[:shared_variable_name],
      :default_class => Config.defaults[:default_class],
      :text_label => Config.defaults[:text_label],
      :create_accessors => [] #:all, :private, :shared, :hash
    }
        
    def initialize(_templates=nil, **options)
      # This is already handled invisibly by the Config module
      #config(**options)
      config[:templates] = _templates if _templates
      @templates = config[:templates].dup || Hash.new
    end

    def build_handler(_template=nil, _initial_object=nil, _parser_backend=nil, **options)
      options = options.filter(AllowableOptions)
      config_merge_options = config.merge(options)
      #(SaxChange.log.info "SaxChange::Parser#build_handler config_merge_options:") if config_merge_options[:log_parser]
      #(SaxChange.log.info config_merge_options.to_yaml) if config_merge_options[:log_parser]
      parser_backend = _parser_backend || config_merge_options[:backend]
      handler_class = get_backend(parser_backend)

      #template_prefix = config_merge_options[:template_prefix]
      _template = _template || config_merge_options[:template]
      template_object = get_template(_template, **config_merge_options)
      initial_object = _initial_object || config_merge_options[:initial_object]   
      # You don't need to send merged options here, since the handler will merge them when necessary.
      handler = handler_class.new(template_object, initial_object, **options)
      
      (SaxChange.log.info "SaxChange::Parser#build_handler with #{handler_class} and template: #{_template}") if config_merge_options[:log_parser]
      
      handler
    end
    
    def call(io='', _template=nil, _initial_object=nil, _parser_backend=nil, **options)
      options = options.filter(AllowableOptions)
      handler = build_handler(_template=nil, _initial_object=nil, _parser_backend=nil, **options)
      #(SaxChange.log.info "SaxChange::Parser#call with #{handler} and template: #{handler.template}") if config.merge(options)[:log_parser]
      handler.run_parser(io)
      handler
    end # base.build

    alias_method :parse, :call
  
    # Takes backend symbol and returns custom Handler class for specified backend.
    # TODO: Should this be private? Should it accept options?
    #def self.get_backend(parser_backend = config[:backend])
    def get_backend(parser_backend = config[:backend])
      (parser_backend = decide_backend) unless parser_backend
      #puts "Handler.get_backend parser_backend: #{parser_backend}"
      if parser_backend.is_a?(String) || parser_backend.is_a?(Symbol)
        parser_proc = Handler::PARSERS[parser_backend.to_sym][:proc]
        parser_proc.call unless parser_proc.nil? || Handler.const_defined?((parser_backend.to_s.capitalize + 'Handler').to_sym)
        Handler.const_get(parser_backend.to_s.capitalize + "Handler")
      end
    rescue
      raise "Could not load the backend parser '#{parser_backend}': #{$!}"
    end
  
    # Finds a loadable backend and returns its symbol.
    # TODO: Should this be private? Take options?
    #def self.decide_backend
    def decide_backend
      #BACKENDS.find{|b| !Gem::Specification::find_all_by_name(b[1]).empty? || b[0]==:rexml}[0]
      Handler::PARSERS.find{|k,v| !Gem::Specification::find_all_by_name(v[:file]).empty? || k == :rexml}[0]
    rescue
      #puts "Handler.decide_backend raising #{$!}"
      raise "The xml parser could not find a loadable backend library: #{$!}"
    end
    

    # Takes string, symbol, or hash, and returns a (possibly cached) parsing template.
    def get_template(_template, _template_prefix=nil, **options)  #_template_prefix=config[:template_prefix])
      options = options.filter(AllowableOptions)
      _template_prefix = _template_prefix || options[:template_prefix] || config[:template_prefix]
      return _template if !['String', 'Symbol', 'Proc'].include?(_template.class.name)
      
      template_string = case
        when _template.is_a?(Proc); _template.call(options, binding)
        when _template.to_s[/\.[yx].?ml$/i]; _template.to_s
        when _template.is_a?(Symbol); _template.to_s + '.yml'
        else raise "Template '#{_template}' cannot be found."
      end
      
      load_template(template_string, _template_prefix)  #, **options)
    end

    # Does the heavy-lifting of template retrieval.
    def load_template(name, _template_prefix=nil)  #, **options)
      #puts "LOAD_TEMPLATE name: '#{name}', prefix: '#{_template_prefix}'"
      #_template_prefix = _template_prefix || options[:template_prefix] || config[:template_prefix]
      @templates[name] ||= case
        when name.to_s[/\.y.?ml$/i]; (YAML.load_file(File.join(*[_template_prefix, name].compact)))
         # This line might cause an infinite loop.
        when name.to_s[/\.xml$/i]; self.class.build(File.join(*[_template_prefix, name].compact), nil, {'compact'=>true})
        else config[:default_class].new
      end
    rescue #:error
      SaxChange.log.warn "SaxChange::Parser#load_template raised exception: #{$!}"
      {}
    end

  end # Parser
end # SaxChange




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
               # after all the SaxChange::Record instances had been added. This was causing an potential infinite recursion situation.
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
    #puts ["\n+++++ARRAY._merge_object", self.class, (obj.inspect), name, delimiter, prefs, type, options].join(', ')
    case
    # I added the 'values' option to capture values-only from hashes or arrays.
    # This is needed to generate array of database-names from rfm.
    when prefs=='values' && obj.is_a?(Hash); self.concat(obj.values)
    when prefs=='values' && obj.is_a?(Array); self.concat(obj)
    when prefs=='values'; self << obj
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
#       See SaxChange::Connection, when sending self (the connection object) as the initial_object.
# done: 'compact' breaks badly with fmpxmllayout data.
# na  : Do the same thing with 'ignore' as you did with 'attach', so you can enable using the 'attributes' array of the yml model.
# done: Double-check that you're pointing to the correct model/submodel, since you changed all helper-methods to look at curent-model by default.
# done: Make sure all method calls are passing the model given by the calling-method.
# abrt: Give most of the config options a global possibility. (no true global config, but top-level acts as global for all immediate submodels).
# na  : Block attachment methods from seeing parent if parent isn't the current objects true parent (how?).
# done: Handle attach: hash better (it's not specifically handled, but declaring it will block a parents influence).
# done: CaseInsensitiveHash/IndifferentAccess is not working for sax parser.
# na  : Give the yml (and xml) doc the ability to have a top-level hash like "fmresultset" or "fmresultset_yml" or "fmresultset_xml",
#       then you have a label to refer to it if you load several config docs at once (like into a SaxChange::Parser::TEMPLATES constant).
#       Use an array of accepted model-keys  to filter whether loaded template is a named-model or actual model data.
# done: Load up all template docs when SaxChange loads, or when SaxChange::Parser loads. For RFM only, not for parser module.
# done: Move Parser::Handler class methods to Parser, so you can do SaxChange::Parser.parse(io, backend, template, initial_object)
# done: Switch args order in .build methods to (io, template, initial_object, backend)
# done: Change "grammar" to "template" in all code
# done: Change 'cursor._' methods to something more readable, since they will be used in SaxChange and possibly user models.
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
# done: Splash_sax.rb is throwing error when loading User.all when Parser.backend is anything other than :ox.
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
# done: Find a way to get Parser defaults into core class patches.
# done: Check resultset portal_meta in Splash Asset model for field-definitions coming out correct according to sax template.
# done: Make sure SaxChange::Metadata::Field is being used in portal-definitions.
# done: Scan thru SaxChange classes and use @instance variables instead of their accessors, so sax-parser does less work.
# done: Change 'instance' option to 'private'. Change 'shared' to <whatever>.
# done: Since unattached elements won't callback, add their callback to an array of procs on the current cursor at the beginning
#        of the non-attached tag.
# TODO: Handle check-for-errors in non-resultset loads.
# abrt: Figure out way to get doctype from nokogiri. Tried, may be practically impossible.
# TODO: Clean up sax code so that no 'rescue' is needed - if an error happens it should be a legit error outside of Parser.
# TODO: Allow attach:none when using handler.


