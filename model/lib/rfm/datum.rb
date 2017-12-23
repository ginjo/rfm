#require 'delegate'
module Rfm
  module Metadata

    class Datum   #< DelegateClass(Field)

      def get_mapped_name(name, resultset)
        #puts ["\nDATUM#get_mapped_name", "name: #{name}", "mapping: #{resultset.layout.field_mapping.to_yaml}"]
        (resultset && resultset.layout && resultset.layout.field_mapping[name]) || name
      end

      # NOT sure what this method is for. Can't find a reference to it.
      def main_callback(cursor)
        resultset = cursor.top.object
        name = get_mapped_name(@attributes['name'].to_s, resultset)
        field = resultset.field_meta[name]
        data = @attributes['data']
        cursor.parent.object[name.downcase] = field.coerce(data)
      end

      def portal_field_element_close_callback(cursor)
        resultset = cursor.top.object
        table, name = @attributes['name'].to_s.split('::')
        #puts ['DATUM_portal_field_element_close_callback_01', table, name].join(', ')
        name = get_mapped_name(name, resultset)
        field = resultset.portal_meta[table.downcase][name.downcase]
        data = @attributes['data']
        #puts ['DATUM_portal_field_element_close_callback_02', "cursor.parent.object.class: #{cursor.parent.object.class}", "resultset.class: #{resultset.class}", "table: #{table}", "name: #{name}", "field: #{field}", "data: #{data}"]
        #(puts resultset.portal_meta.to_yaml) unless field
        cursor.parent.object[name.downcase] = field.coerce(data)
      end

      # Should return value only.
      def field_element_close_callback(cursor)
        record = cursor.parent.object
        resultset = cursor.top.object

        name = get_mapped_name(@attributes['name'].to_s, resultset)
        field = resultset.field_meta[name]
        data = @attributes['data'] #'data'
        #puts ["\nDATUM", name, record.class, resultset.class, data]
        #puts ["\nDATUM", self.to_yaml]
        record[name] = field.coerce(data)
      end

    end # Field
  end # Metadata
end # Rfm
