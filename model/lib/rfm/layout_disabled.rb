require 'delegate'

module Rfm
  class Layout
    
    attr_reader :field_mapping
    attr_accessor :name, :meta
    def_delegators :meta, :field_controls, :value_lists
#     def_delegators :resultset_meta, :date_format, :time_format, :timestamp_format, :field_meta, :portal_meta, :table

    def initialize(*args, **options)
      @meta = Metadata::LayoutMeta.new(**options)
      @name = options[:layout]
      @loaded = true
    end

  end # Layout
end # Rfm
