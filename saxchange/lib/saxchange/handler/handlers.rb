### THIS FILE SHOULD BE TEMPORARY.
### EACH BACKEND HANDLER SHOULD HAVE ITS OWN FILE.
### STRUCTURE SHOULD BE SaxChange::Handler::LibXML, SaxChange::Handler::Ox, etc... yes?
### or will this clash with 

module SaxChange
  module Handler
  
    #####  SAX PARSER BACKEND HANDLERS  #####
    
    const_defined?(:PARSERS) || PARSERS = {}
    
    PARSERS[:libxml] = {:file=>'libxml-ruby', :proc => proc do
      require 'libxml'
      class LibxmlHandler
        include LibXML
        include XML::Parser::Callbacks
        include Handler
    
        def run_parser(io)
          # parser = case
          #   when (io.is_a?(File) || io.is_a?(StringIO))
          #    XML::Parser.io(io)
          #   when io[/^</]
          #    XML::Parser.io(StringIO.new(io))
          #   else
          #    XML::Parser.io(File.new(io))
          # end
          parser = Parser.io(io)
          parser.callbacks = self
          parser.parse
        end
    
        alias_method :on_start_element, :_start_element
        alias_method :on_end_element, :_end_element
        alias_method :on_characters, :_text
        alias_method :on_internal_subset, :_doctype
      end # LibxmlSax  
    end}
    
    PARSERS[:nokogiri] = {:file=>'nokogiri', :proc => proc do
      require 'nokogiri'
      class NokogiriHandler < Nokogiri::XML::SAX::Document
        include Handler
    
        def run_parser(io)
          parser = Nokogiri::XML::SAX::Parser.new(self)
          # parser.parse case
          #   when (io.is_a?(File) || io.is_a?(StringIO))
          #    io
          #   when io[/^</]
          #    StringIO.new(io)
          #   else
          #    File.new(io)
          # end
          parser.parse(io)
        end
    
        alias_method :start_element, :_start_element
        alias_method :end_element, :_end_element
        alias_method :characters, :_text
      end # NokogiriSax
    end}
    
    PARSERS[:ox] = {:file=>'ox', :proc => proc do
      require 'ox'
      class OxHandler < ::Ox::Sax
        include Handler
    
        def run_parser(io)
          options={:convert_special=>true}
          # case
          # when (io.is_a?(File) || io.is_a?(StringIO)); Ox.sax_parse self, io, options
          # when io.to_s[/^</]; StringIO.open(io){|f| Ox.sax_parse self, f, options}
          # else File.open(io){|f| Ox.sax_parse self, f, options}
          # end
          Ox.sax_parse(self, io, options)
        end
    
        alias_method :start_element, :_start_element
        alias_method :end_element, :_end_element
        alias_method :attr, :_attribute
        alias_method :text, :_text    
        alias_method :doctype, :_doctype  
      end # OxFmpSax
    end}
    
    PARSERS[:rexml] = {:file=>'rexml/document', :proc => proc do
      require 'rexml/document'
      require 'rexml/streamlistener'
      class RexmlHandler
        include REXML::StreamListener
        include Handler
    
        def run_parser(io)
          parser = REXML::Document
          #puts "#{self.class.name}#run_parser io object is a: #{io.class.ancestors}"
          parser.parse_stream(io, self)
        end
    
        alias_method :tag_start, :_start_element
        alias_method :tag_end, :_end_element
        alias_method :text, :_text
        alias_method :doctype, :_doctype
      end # RexmlStream
    end}

  end # Handler
end # SaxChange