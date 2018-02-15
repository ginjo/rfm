# Experimental xml-based sax-parsing template
# TODO: Need to somehow convert label 'element' to 'elements'. Do we need a template-template with an element definition that is picked up at all levels of the tree?
# TODO: Do we need a top-level template section called 'global', where everything there is looked at as a current-model alongside any chosen current cursor model?
# TODO: The above should be easy: Just merge @model and @logical_parent_model into the global-model, whenever those two are being set.
#SaxChange::Template.register(SaxChange::Parser.parse(<<EEOOFF, backend:'rexml', template:{'compact_default'=>true}))
SaxChange::Template.register_xml(<<EEOOFF)

<?xml version="1.0" encoding="UTF-8"?>
  <name>fmresultset_xml</name>
  <attach-elements>private</attach-elements>
  <element>
    <name>fmresultset</name>
    <initial_object>Rfm::Resultset</initial_object>
  </element>
  <element>
    <name>datasource</name>
    <initial_object>Hash</initial_object>
  </element>
  <element>
    <name>metadata</name>
    <initial_object>Rfm::Metadata</initial_object>
    <element>
      <name>field_definition</name>
      <as-name>field_meta</as-name>
      <attach>hash</attach>
    </element>
    <element>
      <name>portal_definition</name>
      <as-name>portal_meta</as-name>
      <attach>hash</attach>
    </element>
  </element>
  <element>
    <name>resultset</name>
    <attach-attributes>private</attach-attributes>
  </element>
  <element>
    <name>record</name>
    <initial_object>Rfm::Record</initial_object>
    <attach-attributes>private</attach-attributes>
    <attach>hash</attach>
    <element>
      <name>field</name>
      <initial_object>Rfm::Metadata::Field</initial_object>
      <attach-attributes>private</attach-attributes>
      <compact>true</compact>
      <attach>none</attach>
      <before-close>proc {@object.build_record_data}</before-close>
    </element>
    <element>
      <name>relatedset</name>
      <initial_object>Hash</initial_object>
      <attach>private</attach>
      <as-name>portals</as-name>
      <delimiter>table</delimiter>
      <element>
        <name>record</name>
        <initial_object>Rfm::Record</initial_object>
        <attach-attributes>private</attach-attributes>
        <element>
          <name>field</name>
          <compact>true</compact>
          <initial_object>Rfm::Metadata::Field</initial_object>
          <attach>none</attach>
          <before-close>proc {@object.build_record_data}</before-close>
        </element>
      </element>
    </element>
  </element>
EEOOFF

