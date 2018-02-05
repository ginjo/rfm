# http://www.rubydoc.info/gems/libxml-ruby/2.7.0/LibXML/XML/SaxParser/Callbacks
require 'libxml'
module SaxChange
  module Handler
      class LibxmlRubyHandler
        include Handler
        include LibXML
        include XML::SaxParser::Callbacks
            
        def run_parser(io)
          #puts "LibxmlRubyHandler#run_parser"
          parser = case
            when io.is_a?(IO); XML::SaxParser.io(io)
            when io.is_a?(String); XML::SaxParser.string(io)
            else XML::SaxParser.io(io)
          end
          parser.callbacks = self
          parser.parse
        end
    
        alias_method :on_start_element, :_start_element
        alias_method :on_end_element, :_end_element
        alias_method :on_characters, :_text
        alias_method :on_cdata_block, :_cdata
        alias_method :on_error, :_error
      end # LibxmlRubyHandler
  end
end

