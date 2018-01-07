require 'delegate'

module SaxChange
  class Handler
    #PARSERS[:ox] = {:file=>'ox', :proc => proc do
      
    class OxHandler < Handler
      
      @label = :ox
      @file = 'ox'
      
      def self.setup
        require 'ox'
        Ox::Sax.new
      end
        
      def run_parser(io)        
        options={:convert_special=>true}
        Ox.sax_parse(self, io, options)
      end
  
      alias_method :start_element, :_start_element
      alias_method :end_element, :_end_element
      alias_method :attr, :_attribute
      alias_method :text, :_text    
      alias_method :doctype, :_doctype  
      
    end # OxHandler
  end
end