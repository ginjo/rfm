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
# Moved to rfm-core, since saxchange might be used without rfm-model.
# SaxChange::AllowableOptions.push %w(
#   grammar
#   field_mapping
#   decimal_separator
#   layout
#   connection
#   local_env
# )

# Set SaxChange defaults.
SaxChange::Config.defaults.merge!(
  :default_class => Rfm::CaseInsensitiveHash,
  :template_prefix => File.join(File.dirname(__FILE__), 'saxchange/'),
  # This lambda-proc should resolve to a filename.
  :template => ->(options, env_binding){
      gr_str = options[:grammar].to_s.downcase
      gr_str.size >0 ? gr_str + '.yml' : nil
    },
)


module Rfm
  extend Forwardable

  # Set default parser/formatter for Rfm (this is at the Rfm::Config class-level)
  module Config
    using Refinements
    
    # Rewrite this like this: defaults[:parser] ||= ...
    # Same with formatter.
    #puts "MODEL setting formatter"
    defaults.merge!({
      parser: SaxChange::Parser.new,
      formatter: ->(io, options) do
        handler = options[:parser].call(io, options)
          # TODO: Is this the right place to check for errors?
          #       Or should it be in the template/model? Somewhere else?
        error = handler.result.respond_to?(:error) && handler.result.error
        options[:local_env][:check_for_errors, error]
        handler.result
      end
    })
  end # Config

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
  end # Metadata
  
  def_delegators 'Rfm::Resultset', :load_data
  
  #extend self

end # Rfm

