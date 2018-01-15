module SaxChange
  PATH = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)

  require 'logger'
  
  # TODO: Use submodules to pull gist of Refinements down to each gem within rfm repo.
  # TODO: Also use submidules to pull in generic Config class in both saxchange and rfm-core.
  #
  # Dynamically load generic Refinements and Config under the above module.
  eval(File.read(File.join(File.dirname(__FILE__), './ginjo_tools/refinements.rb')))
  using Refinements
  
  eval(File.read(File.join(File.dirname(__FILE__), './ginjo_tools/config.rb'))) 

  RUBY_VERSION_NUM = RUBY_VERSION[0,3].to_f

  singleton_class.extend Forwardable
  singleton_class.def_delegators Config, :defaults, :'defaults='
  singleton_class.def_delegators :'SaxChange::Parser', :parse
  
  AllowableOptions = %w(
    backend
    default_class
    initial_object
    logger
    log_parser
    text_label
    tag_translation
    shared_variable_name
    template
    templates
    template_prefix
  ).compact.uniq
    
  # These defaults can be set here or in any ancestor/enclosing module or class,
  # as long as the defaults or their constants can be seen from this POV.
  #
  #  Default class MUST be a descendant of Hash or respond to hash methods !!!
  #   
  # For backend, use :libxml, :nokogiri, :ox, :rexml, or anything else, if you want it to always default
  # to something other than the fastest backend found.
  # Using nil will let the Parser decide.
  Config.defaults = {
    :default_class => Hash,
    :backend => nil,
    :text_label => 'text',
    :tag_translation => lambda {|txt| txt.gsub(/\-/, '_').downcase},
    :shared_variable_name => 'attributes',
    :template_prefix => nil,
    :logger => Logger.new($stdout),
  }
  
  def self.log
    defaults[:logger]
  end

end # SaxChange

require 'saxchange/object_merge_refinements'
require 'saxchange/parser'
require 'saxchange/cursor'
require 'saxchange/handler'

# # Require multiple files in a dir.
# multiple_dirs = Dir[File.join(File.dirname(__FILE__), "saxchange/handler/*")]
# multiple_dirs.each do |f|
#   require f
# end




# ####  NOTES and TODOs for SaxParser  ####
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



