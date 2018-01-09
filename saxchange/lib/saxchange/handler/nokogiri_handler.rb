require 'nokogiri'
module SaxChange
  module Handler
    class NokogiriHandler < Nokogiri::XML::SAX::Document
      include Handler

      def run_parser(io)
        Nokogiri::XML::SAX::Parser.new(self).parse(io)  #, 'UTF-8')
      end
  
      alias_method :start_element, :_start_element
      alias_method :end_element, :_end_element
      alias_method :characters, :_text
      alias_method :xmldecl, :_doctype
    end # NokogiriHandler
  end
end

