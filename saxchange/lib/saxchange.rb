module SaxChange
  PATH = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)

  require 'logger'
  
  # TODO: Use submodules to pull gist of Refinements down to each gem within rfm repo.
  # TODO: Also use submidules to pull in generic Config class in both saxchange and rfm-core.
  #
  # Dynamically load generic Refinements and Config under the above module.
  eval(File.read(File.join(File.dirname(__FILE__), './refinements/refinements.rb'))) 
  eval(File.read(File.join(File.dirname(__FILE__), './config/config.rb'))) 

  RUBY_VERSION_NUM = RUBY_VERSION[0,3].to_f

  singleton_class.extend Forwardable
  singleton_class.def_delegators Config, :defaults, :'defaults='
  
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
    #:templates => nil,
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
require 'saxchange/handler/handlers'



###  Regular code ends here  ###

__END__









# ###  PROTOTYPE SAXCHANGE CLASS & MODULE HIERARCHY  ###
# ###  Uncomment this entire section and remove __END__ to 
# 
# require 'rfm/core'
# require 'saxchange/config'
# 
# 
# module SaxChange
# 
#   extend Forwardable
#   singleton_class.def_delegators Config, :defaults
#   
#   Config.defaults = {
#     :default_class => Hash,
#     :backend => nil,
#     :text_label => 'text',
#     :tag_translation => lambda {|txt| txt.gsub(/\-/, '_').downcase},
#     :shared_variable_name => 'attributes',
#     :templates => {},
#     :template_prefix => nil,
#     :logger => Logger.new($stdout)
#   }
#     
#   ### End SaxChange module setup ###
#   
#   
#   
#   class Parser
#     prepend Config
#   end # Parser
#   
#   class Cursor
#     prepend Config
#     
#     attr_accessor :model, :local_model, :object, :tag, :handler, :parent, :level, :element_attachment_prefs, :new_element_callback, :initial_attributes
#     #DEFAULT_CLASS
#     #SaxChange
#     
#   end
#   
#   module Handler
#     prepend Config
#     
#     def self.included(other)
#       other.send :prepend, Config
#     end
#     
#     attr_accessor :stack, :template, :initial_object, :stack_debug, :template_prefix
#     #BACKEND
#     #PARSERS
#     #DEFAULT_CLASS
#     #PARSER_DEFAULTS
#     #TEMPLATE_PREFIX
#     #TEMPLATES
#     #TAG_TRANSLATION
#     #RUBY_VERSION_NUM
#     #TEST_LABEL
#     
#     # Parser
#     # Cursor
#     # 
#     # class LibxmlHandler
#     #   include Handler
#     # end
#     # 
#     # class NokogiriHandler
#     #   include Handler
#     # end
#     # 
#     # class OxHandler
#     #   include Handler
#     # end
#     # 
#     # class RexmlHandler
#     #   include Handler
#     # end
#   end
#   
# end # SaxChange

