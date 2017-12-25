module SaxChange
  PATH = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)
end

require 'saxchange/config'
require 'saxchange/parser'
require 'saxchange/cursor'
require 'saxchange/handler'
require 'saxchange/handler/handlers'


# Regular code ends here.
__END__




###  PROTOTYPE SAXCHANGE CLASS & MODULE HIERARCHY  ###
require 'rfm/core'
require 'saxchange/config'


module SaxChange

  extend Forwardable
  def_delegators :Config, :defaults, :config
  
  Config.defaults = {
    :default_class => Hash,
    :backend => nil,
    :text_label => 'text',
    :tag_translation => lambda {|txt| txt.gsub(/\-/, '_').downcase},
    :shared_variable_name => 'attributes',
    :templates => {},
    :template_prefix => nil,
    :logger => Logger.new($stdout)
  }
      
  ::Object.const_set(:ATTACH_OBJECT_DEFAULT_OPTIONS, {
    :shared_variable_name => 'SHARED_VARIABLE_NAME',
    :default_class => 'DEFAULT_CLASS',
    :text_label => 'TEXT_LABEL',
    :create_accessors => [] #:all, :private, :shared, :hash
  })
    
  ### End SaxChange module setup ###
  
  
  class Parser
    include Config
  end # Parser
  
  class Cursor
    include Config
    
    attr_accessor :model, :local_model, :object, :tag, :handler, :parent, :level, :element_attachment_prefs, :new_element_callback, :initial_attributes
    #DEFAULT_CLASS
    #SaxChange
    
  end
  
  module Handler
    include Config
    
    # def self.included(other)
    #   other.send :include, Config
    # end
    
    attr_accessor :stack, :template, :initial_object, :stack_debug, :template_prefix
    #BACKEND
    #PARSERS
    #DEFAULT_CLASS
    #PARSER_DEFAULTS
    #TEMPLATE_PREFIX
    #TEMPLATES
    #TAG_TRANSLATION
    #RUBY_VERSION_NUM
    #TEST_LABEL
    
    Parser
    Cursor
  
    class LibxmlHandler
      include Handler
    end
    
    class NokogiriHandler
      include Handler
    end
    
    class OxHandler
      include Handler
    end
    
    class RexmlHandler
      include Handler
    end
  end
  
end