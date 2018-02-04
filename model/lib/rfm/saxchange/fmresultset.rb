SaxChange::Template.register(YAML.load(<<-EEOOFF))


#!/usr/bin/env ruby
# YAML structure defining a SAX parsing scheme for fmresultset xml.
# The initial object of this parse should be a new instance of Rfm::Resultset.
---
# This first function doesn't work anymore, since config[:layout] is not available in the parser environment.
#initial_object: "Rfm::Resultset.new(Rfm::Layout.new(config[:layout]))"
#initial_object: "Rfm::Resultset.new(Rfm::Layout.new('temp_name_until_Rfm_Resultset_class_is_fixed_and_layout_name_is_generated_from_xml_data'))"
initial_object: proc { Rfm::Resultset.new(**config) }
attach_elements: _meta
attach_attributes: _meta
create_accessors: all
# Name is not functionally necessary, but I'm using it to debug cursor stack.
name: fmresultset
elements:
# Note: doctype callback is different for different backends.
- name: doctype
  #attach_attributes: hash
- name: fmresultset
  attach: none
- name: product
  #attach_attributes: hash
- name: error
  attach: none
  # I've disabled this for v4.
  #before_close: :check_for_errors
  attributes:
  - name: code
    as_name: error
- name: datasource
  attach: none
  #before_close: ['@logical_parent.object', end_datasource_element_callback, self]
  before_close: proc { @logical_parent.object.end_datasource_element_callback(self) }
  attributes:
  - name: total_count
    accessor: none
- name:  metadata
  attach: none
- name: field_definition
  # These two steps can be used to create the attachment to resultset-meta automatically,
  # but the field-mapping translation won't happen.
  # attach: [_meta, 'Rfm::Metadata::Field', allocate]
  # as_name: field_meta
  #attach: [none, 'Rfm::Metadata::Field', ':allocate']
  initial_object: proc { Rfm::Metadata::Field.allocate }
  attach: none
  delimiter: name
  attach_attributes: private
  #before_close: [object, field_definition_element_close_callback, self]
  before_close: proc { @object.field_definition_element_close_callback(self) }
- name: relatedset_definition
  delimiter: table
  as_name: portal_meta
  attach_attributes: private
  elements:
  - name: field_definition
    #attach: [none, 'Rfm::Metadata::Field', ':allocate']
    initial_object: proc { Rfm::Metadata::Field.allocate }
    attach: none
    delimiter: name
    as_name: field_meta
    attach_attributes: private
    #before_close:  [object, relatedset_field_definition_element_close_callback, self]
    before_close: proc { @object.relatedset_field_definition_element_close_callback(self) }
- name: resultset
  attach: none
  attributes:
  - name: count
    accessor: none
  - name: fetch_size
    accessor: none
- name: record
  ##attach: [cursor, object, handle_new_record, _attributes]
  ##attach_attributes: none
  #attach: [array, 'Rfm::Record', new, object]
  #attach: 'proc {|env| puts "Inside fmresultset record template proc"; ["array", "Rfm::Record", "new", "object"]}'
  initial_object: proc { Rfm::Record.new(@object) }
  attach: |
    proc do |env|
      #puts 'inside attachment proc'
      record_proc = handler.config[:record_proc]
      if record_proc.is_a?(Proc)
        instance_exec(@object, top.object, env, &record_proc)
      else;
        # TODO: Neither of these work here, because by this time
        #       the 'prefs' variable has been mutated in 'attach_new_element'
        #['array', 'Rfm::Record', 'new', 'object']
        'array'
      end
    end
  attach_attributes: private
  #before_close: '@loaded=true'
  before_close: proc { @object.instance_variable_set(:@loaded, true) }
  elements:
  - name: field
    #attach: [none, 'Rfm::Metadata::Datum', ':allocate']
    initial_object: proc { Rfm::Metadata::Datum.allocate }
    # This is like previous attach:cursor.
    # It skips attaching this element, but still allows 
    # sub-elements & attributes to attach to it.
    attach: hidden
    # This does the same thing but requires attach_attributes:shared and attach_elements:shared
    #attach: none
    #attach_attributes: shared
    #attach_elements: shared
    compact: false
    #before_close: [object, field_element_close_callback, self]
    before_close: proc { @object.field_element_close_callback(self) }
  - name: relatedset
    #attach: [private, Array, ':allocate']
    initial_object: proc { Array.allocate }
    attach: private
    as_name: portals
    attach_attributes: private
    create_accessors: all
    delimiter: table
    elements:
    - name: record
      #class: Rfm::Record
      #attach: [default, 'Rfm::Record', ':allocate']
      initial_object: proc { Rfm::Record.allocate }
      attach: default
      attach_attributes: private
      #before_close: '@loaded=true'
      before_close: proc { @object.instance_variable_set(:@loaded, true) }
      elements:
      - name: field
        compact: true
        #attach: [none, 'Rfm::Metadata::Datum', ':allocate']
        initial_object: proc { Rfm::Metadata::Datum.allocate }
        attach: none
        #before_close: [object, portal_field_element_close_callback, self]
        before_close: proc { @object.portal_field_element_close_callback(self) }
        # This is needed, because in v4 top-level attachment declarations affect ALL models.
        # attach_attributes: shared
        # attach_elements: shared
        # elements:
        # - name: data
        #   attach_attributes: hash


EEOOFF