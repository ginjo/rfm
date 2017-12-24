

# This is required because rfm-core does not specifically require it.
# This is a rfm-model feature.
require 'rfm/case_insensitive_hash'

# TODO: Consider removing the rfm-xxx.rb files and just requiring rfm/xxx.
#       But how would the sub-gem's lib dir be added to PATH then?
require 'rfm-core'
require 'saxchange'


class Rfm::SaxParser

  # TODO: This should not be a global setting.
  # This should be specified when SaxParser or Connection object is instanciated by rfm-model.
  parser_defaults = {
    :default_class => Rfm::CaseInsensitiveHash,
    :template_prefix => File.join(File.dirname(__FILE__), 'sax/'),
    :templates => {
      :fmpxmllayout => 'fmpxmllayout.yml',
      :fmresultset => 'fmresultset.yml',
      :fmpxmlresult => 'fmpxmlresult.yml',
      :none => nil
    }
  }
  
  if const_defined?(:PARSER_DEFAULTS)
    PARSER_DEFAULTS.merge! parser_defaults
  else
    PARSER_DEFAULTS = parser_defaults
  end
  
end


module Rfm

  autoload :Server,       'rfm/server'
  autoload :Database,     'rfm/database'
  autoload :Layout,       'rfm/layout'
  autoload :Resultset,    'rfm/resultset'
  autoload :Record,       'rfm/record'
  autoload :Base,         'rfm/base'
  autoload :SaxParser,    'rfm/parsers/sax'
  autoload :Config,       'rfm/config'
  autoload :Factory,      'rfm/factory'
  autoload :CompoundQuery,'rfm/compound_query'
  autoload :VERSION,      'rfm/version'
  autoload :Scope,        'rfm/scope.rb'

  module Metadata
    autoload :Script,         'rfm/script'
    autoload :Field,          'rfm/field'
    autoload :FieldControl,   'rfm/field_control'
    autoload :ValueListItem,  'rfm/value_list_item'
    autoload :Datum,          'rfm/datum'
    autoload :ResultsetMeta,  'rfm/resultset_meta'
    autoload :LayoutMeta,     'rfm/layout_meta'
  end

  def_delegators 'Rfm::Factory', :servers, :server, :db, :database, :layout
  def_delegators 'Rfm::Config', :config, :get_config, :config_clear
  def_delegators 'Rfm::Resultset', :load_data

  def models(*args)
    Rfm::Factory.models(*args)
  end

  def modelize(*args)
    Rfm::Factory.modelize(*args)
  end
  
  extend self

end # Rfm