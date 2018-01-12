require 'ox'
module SaxChange
  module Handler
    class OxHandler < Ox::Sax
      include Handler

      def run_parser(io)        
        options={:convert_special=>true}
        puts "OxHandler#run_parser self: #{self}, io: #{io}, io.stat: #{io.stat.inspect}"
        #puts "IO#read"
        #puts io.read
        #io.rewind
        #io.set_encoding('UTF-8')
        Ox.sax_parse(self, io, options)
      end
      
      
      ### These hard-coded methods still don't help ox::sax parsing of file io.
      
      def start_element(*args)
        _start_element(*args)
      end
      
      def end_element(*args)
        _end_element(*args)
      end

      def attr(*args)
        _attribute(*args)
      end
      
      def text(*args)
        _text(*args)
      end
      
      def doctype(*args)
        _doctype(*args)
      end
  
      # alias_method :start_element, :_start_element
      # alias_method :end_element, :_end_element
      # alias_method :attr, :_attribute
      # alias_method :text, :_text    
      # alias_method :doctype, :_doctype  
    end # OxHandler
  end
end