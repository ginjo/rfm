require 'ox'
module SaxChange
  module Handler
    class OxHandler < Ox::Sax
      include Handler

      def run_parser(io)        
        options={:convert_special=>true}
        puts "OX Handler run_parser self: #{self.class.ancestors}, io: #{[io, io.class.ancestors]}"
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