module SaxChange
  class Handler
    class NokogiriHandler < Handler
      @label = :nokogiri
      @file  = 'nokogiri'
      @setup = proc do
        require 'nokogiri'
        #Nokogiri::XML::SAX::Document.send :inherited, self
      end
      @backend_instance = 'Nokogiri::XML::SAX::Document.new'

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


# # This demonstrates a working nokogiri sax parser.
# # Run this with a 'File.read(...)' as input.
# module SaxChange
#   class Handler
#     require 'nokogiri'
#     class NokogiriHandler < Nokogiri::XML::SAX::Document
#       @label = :nokogiri
#       @file  = 'nokogiri'
#       @setup = proc do
#         require 'nokogiri'
#         #Nokogiri::XML::SAX::Document.send :inherited, self
#       end
#       #@backend_instance = 'Nokogiri::XML::SAX::Document.new'
# 
#       def run_parser(io)
#         Nokogiri::XML::SAX::Parser.new(self).parse(io)
#       end
#       
#       def go(*args)
#         puts args
#       end
#   
#       alias_method :start_element, :go
#       alias_method :end_element, :go
#       alias_method :characters, :go
#       alias_method :xmldecl, :go
#     end # NokogiriHandler
#   end
# end

