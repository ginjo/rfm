# http://code.yorickpeterse.com/oga/latest/Oga/XML/SaxParser.html
require 'oga'
module SaxChange
  module Handler
    class OgaHandler
      include Handler

      def run_parser(io)        
        Oga::XML::SaxParser.new(self, io).parse
      end
  
      #alias_method :on_attribute, :_attribute
      alias_method :on_text, :_text    
      alias_method :on_doctype, :_doctype
      alias_method :on_cdata, :_cdata
      alias_method :on_xml_decl, :_xmldecl
      
      def on_element(namespace, name, attributes)
        _start_element(name, attributes)
      end
      
      def after_element(namespace, name)
        _end_element(name)
      end
      
    end # OgaHandler
  end
end