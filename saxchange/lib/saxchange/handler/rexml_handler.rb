module SaxChange
  class Handler

    class RexmlHandler < Handler
    
      @label = :rexml
      @file  = 'rexml/document'
    
      def self.setup
        require 'rexml/document'
        require 'rexml/streamlistener'
        include REXML::StreamListener
        nil
      end
    
      def run_parser(io)
        REXML::Document.parse_stream(io, self)
      end
    
      alias_method :tag_start, :_start_element
      alias_method :tag_end, :_end_element
      alias_method :text, :_text
      alias_method :doctype, :_doctype
    end # RexmlHandler
  end
end

