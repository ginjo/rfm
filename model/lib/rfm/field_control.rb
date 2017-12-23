module Rfm
  module Metadata

    # The FieldControl object represents a field on a FileMaker layout. You can find out what field
    # style the field uses, and the value list attached to it.
    #
    # =Attributes
    #
    # * *name* is the name of the field
    #
    # * *style* is any one of:
    # * * :edit_box - a normal editable field
    # * * :scrollable - an editable field with scroll bar
    # * * :popup_menu - a pop-up menu
    # * * :checkbox_set - a set of checkboxes
    # * * :radio_button_set - a set of radio buttons
    # * * :popup_list - a pop-up list
    # * * :calendar - a pop-up calendar
    #
    # * *value_list_name* is the name of the attached value list, if any
    # 
    # * *value_list* is an array of strings representing the value list items, or nil
    #   if this field has no attached value list
    class FieldControl
      attr_reader :name, :style, :value_list_name
      meta_attr_accessor :layout_meta

      FIELD_CONTROL_STYLE_MAP = {
        'EDITTEXT'  =>  :edit_box,
        'POPUPMENU'  =>  :popup_menu,
        'CHECKBOX'  =>  :checkbox_set,
        'RADIOBUTTONS'  =>  :radio_button_set,
        'POPUPLIST'  =>  :popup_list,
        'CALENDAR'  =>  :calendar,
        'SCROLLTEXT'  =>  :scrollable,
      }

      # def initialize(_attributes, meta)
      #   puts ["\nFieldControl#initialize", "_attributes: #{_attributes}", "meta: #{meta.class}"]
      #   self.layout_meta = meta
      #   _attach_as_instance_variables(_attributes) if _attributes
      #   self
      # end

      def initialize(meta)
        #puts ["\nFieldControl#initialize", "meta: #{meta.class}"]
        self.layout_meta = meta
        self
      end

      # # Handle manual attachment of STYLE element.
      # def handle_style_element(attributes)
      #   _attach_as_instance_variables attributes, :key_translator=>method(:translate_value_list_key), :value_translator=>method(:translate_style_value)
      # end
      # 
      # def translate_style_value(key, val)
      #   #puts ["TRANSLATE_STYLE", raw].join(', ')
      #   {
      #     'EDITTEXT'  =>  :edit_box,
      #     'POPUPMENU'  =>  :popup_menu,
      #     'CHECKBOX'  =>  :checkbox_set,
      #     'RADIOBUTTONS'  =>  :radio_button_set,
      #     'POPUPLIST'  =>  :popup_list,
      #     'CALENDAR'  =>  :calendar,
      #     'SCROLLTEXT'  =>  :scrollable,
      #   }[val] || val
      # end

      # def translate_value_list_key(raw)
      #   {'valuelist'=>'value_list_name'}[raw] || raw
      # end

      def value_list
        layout_meta.value_lists[value_list_name]
      end

      def element_close_handler  #(_cursor)
        @type = FIELD_CONTROL_STYLE_MAP[@type] || @type
        layout_meta.receive_field_control(self)
      end

    end
  end
end
