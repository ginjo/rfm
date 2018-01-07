require 'delegate'

module SaxChange
  class Handler
    #PARSERS[:ox] = {:file=>'ox', :proc => proc do
      
    class OxHandler < Handler
      
      @label = :ox
      @file = 'ox'
      @backend_parser_class = 'Ox::Sax'
        
      def run_parser(io)
        #super
        #raise_if_bad_io(io) # was 'super'
        
        options={:convert_special=>true}
        # case
        # when (io.is_a?(File) || io.is_a?(StringIO)); Ox.sax_parse self, io, options
        # when io.to_s[/^</]; StringIO.open(io){|f| Ox.sax_parse self, f, options}
        # else File.open(io){|f| Ox.sax_parse self, f, options}
        # end
        # I had to put the eof? here, since it prevents connection thread exceptions
        # from mucking up Ox's parser. None of the other parsers have this issue.
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