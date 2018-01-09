require 'forwardable'

# This is required because rfm-core does not specifically require it.
# This is a rfm-model feature.
require 'rfm/case_insensitive_hash'

# TODO: Consider removing the rfm-xxx.rb files and just requiring rfm/xxx.
#       But how would the sub-gem's lib dir be added to PATH then?
require 'rfm-core'
#require 'saxchange/config'
require 'saxchange'

# This is needed to serve the proc below, which is inserted into the parser defaults.
SaxChange::AllowableOptions.push %w(
  grammar
  field_mapping
  decimal_separator
  layout
  connection
)

SaxChange::Config.defaults.merge!({
  :default_class => Rfm::CaseInsensitiveHash,
  #:initial_object => proc { Rfm::Resultset.new(Rfm::Layout.new('test'), Rfm::Layout.new('test')) },
  :template_prefix => File.join(File.dirname(__FILE__), 'saxchange/'),
  :template => ->(options, env_binding){ options[:grammar].to_s.downcase + '.yml' },
})


module Rfm
  extend Forwardable

  #autoload :Server,       'rfm/server'
  #autoload :Database,     'rfm/database'
  #autoload :Layout,       'rfm/layout'
  autoload :Resultset,    'rfm/resultset'
  autoload :Record,       'rfm/record'
  autoload :Base,         'rfm/base'

  module Metadata
    autoload :Script,         'rfm/script'
    autoload :Field,          'rfm/field'
    autoload :FieldControl,   'rfm/field_control'
    autoload :ValueListItem,  'rfm/value_list_item'
    autoload :Datum,          'rfm/datum'
    autoload :ResultsetMeta,  'rfm/resultset_meta'
    autoload :LayoutMeta,     'rfm/layout_meta'
  end
  
  def_delegators 'Rfm::Resultset', :load_data

  # Disabled by wbr for v4.
  #
  #   def models(*args)
  #     Rfm::Factory.models(*args)
  #   end
  # 
  #   def modelize(*args)
  #     Rfm::Factory.modelize(*args)
  #   end
  
  extend self

end # Rfm
