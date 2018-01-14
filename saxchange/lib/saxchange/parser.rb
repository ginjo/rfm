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
        
    def initialize(_templates=nil, **options)
      self.templates = _templates.dup || config.delete(:templates).dup || Hash.new
    end

    def build_handler(_template=nil, _initial_object=nil, _backend=nil, **options)
      # Handler.new(_template, _initial_object, _backend, **options).tap do |h|
      #   h.parser = self
      # end
      #
      # Handler.allocate.tap do |h|
      #   h.parser = self
      #   h.send :initialize, _template, _initial_object, _backend, **options
      # end
      Handler.new(_template, _initial_object, _backend, **options) do
        self
      end
    end
    
    def parse(io='', _template=nil, _initial_object=nil, _backend=nil, **options)
      handler = build_handler(_template, _initial_object, _backend, **options)
      handler.run_parser(io)
      handler
    end
    
    def call(*args)
      parse(*args).result
    end

  end # Parser
end # SaxChange


# ####  NOTES and TODOs for Rfm SaxParser  ####
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


