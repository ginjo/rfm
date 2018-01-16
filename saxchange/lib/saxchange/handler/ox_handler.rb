# http://www.rubydoc.info/github/ohler55/ox/Ox/Sax
require 'ox'
module SaxChange
  module Handler
    class OxHandler < Ox::Sax
      include Handler

      def run_parser(io)        
        options={:convert_special=>true}
        # Dunno why but need this for ox to parse File io,
        # but only when using ox with this library (gem).
        # When Ox.sax_parse is used standalone, or even with this lib's
        # OxHandler, it works fine.
        io.respond_to?(:pos) && io.is_a?(File) && io.pos
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