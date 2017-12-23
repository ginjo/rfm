module Rfm
  module Metadata
    class LayoutMeta < CaseInsensitiveHash

      def initialize(layout)
        @layout = layout
      end

      def field_controls
        self['field_controls'] ||= CaseInsensitiveHash.new
      end

      def field_names
        field_controls.values.collect{|v| v.name}
      end

      def field_keys
        field_controls.keys
      end

      def value_lists
        self['value_lists'] ||= CaseInsensitiveHash.new
      end

      # def handle_new_field_control(attributes)
      #   name = attributes['name']
      #   field_control = FieldControl.new(attributes, self)
      #   field_controls[get_mapped_name(name)] = field_control
      # end

      def receive_field_control(fc)
        #name = fc.name
        field_controls[get_mapped_name(fc.name)] = fc
      end

      # Should this be in FieldControl object?
      def get_mapped_name(name)
        (@layout.field_mapping[name]) || name
      end

    end
  end
end
