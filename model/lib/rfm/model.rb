require 'forwardable'

# This is required because rfm-core does not specifically require it.
# This is a rfm-model feature.
require 'rfm/case_insensitive_hash'

# TODO: Consider removing the rfm-xxx.rb files and just requiring rfm/xxx.
#       But how would the sub-gem's lib dir be added to PATH then?
require 'rfm-core'
#require 'saxchange/config'
require 'saxchange'

# # Loads all sax parsing templates (ruby).
# multiple_dirs = Dir[File.join(File.dirname(__FILE__), "saxchange/*.rb")]
# multiple_dirs.each do |f|
#   require f
# end

# Set SaxChange defaults.
SaxChange::Config.defaults.merge!(
  :default_class => Rfm::CaseInsensitiveHash,
  # This lambda-proc should resolve to a filename.
  :template => ->(options, env_binding){
      gr_str = options[:grammar].to_s.downcase
      gr_str.size >0 ? gr_str : nil
    },
)


module Rfm
  extend Forwardable

  # Set default parser/formatter for Rfm (this is at the Rfm::Config class-level)
  module Config
    using Refinements
    
    #defaults[:parser] ||= SaxChange::Parser.new
    
    defaults[:formatter] = ->(io, options) do
      handler = options[:parser].call(io, options)
        # TODO: Is this the right place to check for errors?
        #       Or should it be in the template/model? Somewhere else?
      error = handler.result.respond_to?(:error) && handler.result.error
      options[:local_env][:check_for_errors, error]
      options[:debug] ? handler : handler.result
    end
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
  
end # Rfm

# Loads all sax parsing templates (ruby).
multiple_dirs = Dir[File.join(File.dirname(__FILE__), "saxchange/*.rb")]
multiple_dirs.each do |f|
  require f
end
  
