require 'ox'
module SaxChange
  module Handler
    class OxHandler < Ox::Sax
      include Handler
      
      # TODO: This handler doesn't work with file-based io, bacause somehow the io gets read first.
      # Try this:
      # File.open('databases_fmpxmlresult.xml'){|f| SaxChange::Parser.new(backend:'ox', template:{}).parse(f)}
      # See in handler#run_parser the io.rewind option. That fixes this issue.
      
      def run_parser(io)        
        options={:convert_special=>true}
        #puts "OxHandler#run_parser self: #{self}, io: #{io}, io.stat: #{io.stat.inspect}"
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