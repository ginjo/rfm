module Rfm
  module Metadata

    # The ValueListItem object represents an item in a Filemaker value list.
    # ValueListItem is subclassed from String, so you can use it just like
    # a string. It does have three additional methods to help separate Filemaker *value*
    # vs *display* items.
    #
    # Getting values vs display items:
    #
    # * *#value* the value list item value
    #
    # * *#display* is the value list item display. It could be the same
    #   as +value+, or it could be the "second field", if that option is checked in Filemaker
    #
    # * *#value_list_name* is the name of the parent value list, if any
    class ValueListItem < String
      # TODO: re-instate saving of value_list_name.
      attr_reader :value, :display, :value_list_name

      #   def initialize(value, display, value_list_name)
      #     @value_list_name = value_list_name
      #     @value           = value.to_s
      #     @display         = display.to_s
      #     self.replace @value
      #   end

    end # ValueListItem

  end # Metadata
end # Rfm
