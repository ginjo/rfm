module SaxChange
  class Handler
    class NokogiriHandler < Handler    #Nokogiri::XML::SAX::Document
    
      @label = :nokogiri
      @file  = 'nokogiri'
      @setup = proc do
        require 'nokogiri'
      end
      @backend_instance = 'Nokogiri::XML::SAX::Document.new'

      def run_parser(io)
        Nokogiri::XML::SAX::Parser.new(self).parse(io)
      end
  
      alias_method :start_element, :_start_element
      alias_method :end_element, :_end_element
      alias_method :characters, :_text
    end # NokogiriSax
  end
end