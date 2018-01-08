module SaxChange
  class Handler
      class LibxmlHandler < Handler

        @label = :libxml
        @file  = 'libxml-ruby'
        @setup = proc do
          require 'libxml'
          include LibXML
          include LibXML::XML::SaxParser::Callbacks        
        end
    
        def run_parser(io)
          parser = LibXML::XML::Parser.io(io)
          parser.callbacks = self
          parser.parse
        end
    
        alias_method :on_start_element, :_start_element
        alias_method :on_end_element, :_end_element
        alias_method :on_characters, :_text
        alias_method :on_internal_subset, :_doctype
      end # LibxmlSax

  end
end

