SaxChange::Template.register(YAML.load(<<-EEOOFF))

#!/usr/bin/env ruby
# YAML structure defining a SAX parsing scheme for fmpxmllayout xml.
# The initial object of this parse should be a new instance of Rfm::Layout.
---
# This first function doesn't work anymore, since config[:layout] is not available in the parser environment.
#initial_object: "Rfm::Layout.new(config[:layout])"
#initial_object: "Rfm::Layout.new('temp_name_until_Rfm_Layout_class_is_fixed_and_layout_name_is_generated_from_xml_data')"
#initial_object: "Rfm::Layout.new(**options)"
name: fmpxmllayout
initial_object: proc { Rfm::Metadata::LayoutMeta.new(**config) }
attach_elements: hash  #_meta
attach_attributes: hash  #_meta
create_accessors: all
elements:
- name: xmldecl
  attach: hash
# Doctype callback is different for different backends.
# - name: doctype
#   attach: none
#   attributes:
#   - name: value
#     as_name: doctype
- name: fmpxmllayout
  attach: none
- name: errorcode
  attach: none
  # Disabled by wbr for v4.
  #before_close: :check_for_errors
  attributes:
  - name: text
    as_name: error
- name: product
  as_name: product
- name: layout
  attach: none
  attributes:
  - name: database
    as_name: database
  - name: NAME
    as_name: name
- name: field
  # attach:
  # - cursor
  # - Rfm::Metadata::FieldControl
  # - :new
  # #- ivg(:meta)
  # - top.object
  initial_object: proc { Rfm::Metadata::FieldControl.new(top.object) }
  attach: skip
  delimiter: name
  # Must use before_close handler to attach, since field_mapping must be applied to value-list key name.
  #before_close: [object, ':element_close_handler']
  before_close: proc { @object.element_close_handler }
  # # Used to be 'object.meta', but that required sloppy 'loaded' indicator handling (or infinite loop),
  # # so now just referring to raw inst var @meta, instead of method .meta.
  # # Need to assume attributes may or may not be included in start_element call.
  # handler: [object.instance_variable_get('@meta'), handle_new_field_control, _attributes]
  # # attach_attributes isn't doing anything when used with new-element-handler.
  attach_attributes: private
  elements:
  # This config doesn't use the creation handler, so it should work with ox.
  - name: style
    #element_handler: [object, handle_style_element, _attributes]
    attach: none
    #attach: [cursor, object, handle_style_element, _attributes]
    #attach_attributes: none
    attributes:
    - name: valuelist
      as_name: value_list_name
      #translate: translate_style_value
- name: valuelists
  attach: none
- name: valuelist
  #class: Array
  #attach: [_meta, Array, ':new']
  #attach: [hash, Array, ':new']
  initial_object: proc { Array.new }
  attach: hash
  as_name: value_lists
  delimiter: name
  elements:
  - name: value
    #class: Rfm::Metadata::ValueListItem
    #attach: [array, 'Rfm::Metadata::ValueListItem', ':allocate']
    initial_object: proc { Rfm::Metadata::ValueListItem.allocate }
    attach: array
    before_close: proc { replace(@value.to_s) }
    attach_attributes: private
    attributes:
    - name: display
      as_name: display
    - name: text
      as_name: value

EEOOFF

