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
require 'logger'
require 'saxchange/handler'

module SaxChange

  class Parser
    using Refinements
    using ObjectMergeRefinements
  
    # Initialize template cache in singleton-class of Parser,
    # to hide data from casual onlookers.
    meta_attr_accessor :templates
  
    extend Forwardable
    prepend Config
    
    # TODO: Make this block of options passable at loadtime/runtime from connection object to parser object,
    #       because we need ability to pass in the default_class from a client connection instance.
    ::Object::ATTACH_OBJECT_DEFAULT_OPTIONS = {
      :shared_variable_name => Config.defaults[:shared_variable_name],
      :default_class => Config.defaults[:default_class],
      :text_label => Config.defaults[:text_label],
      :create_accessors => [] #:all, :private, :shared, :hash
    }
    
    def self.parse(io, **options)
      new(**options).parse(io)
    end
        
    def initialize(_templates=nil, **options)
      #puts "Parser#initialize with options: #{options}"
      self.templates = _templates.dup || config.delete(:templates).dup || Hash.new
    end

    def build_handler(_backend=nil, _template=nil, _initial_object=nil, **options)
      #puts "Parser#build_handler with options: #{options}" 
      # Note that we need to send the parser instance @config to the handler,
      # since the handler only looks back to the config defaults, not to the parser config.
      Handler.new(_backend, _template, _initial_object, **@config.merge(options)) do
        # Block result becomes Handler#@parser to be used for template cache.
        self
      end
    end
    
    # TODO: Should the _backend arg be first for these two methods?
    def call(io='', _template=nil, _initial_object=nil, _backend=nil, **options)
      #puts "Parser#call with options: #{options}"
      handler = build_handler(_backend, _template, _initial_object, **options)
      handler.run_parser(io)
    # Inserted for debugging. Should probably reraise for runtime & production.
    ensure
      handler.errors << [$!, "  #{$!.backtrace.join("\n  ")}"] if $!
      return handler
    end
    
    # def parse(*args)
    #   call(*args).result
    # end
    
    def parse(io='', _template=nil, _initial_object=nil, _backend=nil, **options)
      #puts "Parser#parse with options: #{options}"
      handler = build_handler(_backend, _template, _initial_object, **options)
      handler.run_parser(io)
    end

  end # Parser
end # SaxChange


