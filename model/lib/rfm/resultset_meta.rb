module Rfm
  module Metadata
    class ResultsetMeta < CaseInsensitiveHash

      def field_meta
        self['field_meta'] ||= CaseInsensitiveHash.new
      end

      def portal_meta
        self['portal_meta'] ||= CaseInsensitiveHash.new
      end

      def date_format
        self['date_format']
      end

      def time_format
        self['time_format']
      end

      def timestamp_format
        self['timestamp_format']
      end

      def total_count
        self['total_count'].to_i
      end    

      def foundset_count
        self['count'].to_i
      end

      def fetch_size
        self['fetch_size'].to_i
      end

      def table
        self['table']
      end

      def error
        self['error']
      end

      def field_names
        field_meta ? field_meta.values.collect{|v| v.name} : []
      end

      def field_keys
        field_meta ? field_meta.keys : []
      end

      def portal_names
        portal_meta ? portal_meta.keys : []
      end

      # def handle_new_field(attributes)
      #   f = Field.new(attributes)
      #   # TODO: Re-enable these when you stop using the before_close callback.
      #   #   name = attributes['name']
      #   #   self[name] = f
      # end

      def layout_object
        self['layout_object']
      end

      def attach_layout_object_from_cursor(cursor)
        self['layout_object'] = cursor.top.object.layout
        #puts ["\nRESULTSET_META#metadata_element_close_callback", self['layout_object']]
      end 

    end
  end
end
