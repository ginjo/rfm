#####  A declarative SAX parser, written by William Richardson  #####
#
# Use:
#   irb -rubygems -I./  -r  lib/rfm/utilities/sax_parser.rb
#   r = Rfm::SaxParser::Handler.build(Rfm::SaxParser::DAT[:fmp], Rfm::SaxParser::OxFmpSax, 'lib/rfm/sax/fmresultset.yml')
#   r = Rfm::SaxParser::OxFmpSax.build(Rfm::SaxParser::DAT[:fmp], 'local_testing/sax_parser.yml')
#   r = Rfm::SaxParser::Handler.build(Rfm::SaxParser::DAT[:fm], Rfm::SaxParser::RexmlStream, 'lib/rfm/sax/fmresultset.yml')
#
#####

#gem 'ox', '1.8.5'
require 'stringio'
require 'ox'
require 'yaml'
require 'rexml/parsers/streamparser'
require 'rexml/streamlistener'
require 'rexml/document'
require 'libxml'
require 'nokogiri'

# FIXME: Text values are not showingi up. 
# TODO: Move test data & user models to spec folder and local_testing.
# TODO: Create special file in local_testing for experimentation & testing - will have user models, grammar-yml, calling methods.
# done: Move attribute/text buffer from sax handler to cursor.
# TODO: Add option to 'compact' unnecessary or empty elements/attributes - maybe - should this should be handled at Model level?
# done: Add nokogiri, libxml-ruby, rexml interfaces.
# TODO: Separate all attribute options in yml into attributes: hash, similar to elements: hash.
# TODO: Handle multiple 'text' callbacks for a single element.
# TODO: Add options for text handling (what to name, where to put).
# TODO: Allow nil as yml document - parsing will be generic. But throw error if given yml doc can't open.
# TODO: Put the attribute sending back in the handler, and only send it at once - we need to be able to filter/sort on attributes when element comes in and object is created.
#				Store a lambda of each attachment call in a "silo". The call them out one by one when the parent closes, causing child to attach to parent.
#				... and now doing that, but doesn't seem to be working. See methods with attachment_procs for more info.
#       Currently, the attachment proces aren't triggering "merge_elements"


module Rfm
	module SaxParser
	
		class Cursor
		
		    attr_accessor :_model, :_obj, :_tag, :_parent, :_top, :_stack, :_new_tag
		    
		    def self.constantize(klass)
			  	SaxParser.const_get(klass.to_s)
		  	rescue
		  		#puts "Error: cound not constantize '#{klass.to_s}': #{$!}" unless klass.to_s == ''
			  	nil
			  end
		    
		    def initialize(model, obj, tag)
		    	@_tag   = tag
		    	@_model = model
		    	@_obj   = obj.is_a?(String) ? constantize(obj).new : obj
		    	@attachment_procs = []
		    	self
		    end
		    
		    
		    
		    #####  SAX METHODS  #####
		    
		    def attribute(name, value)
		    	return if (_model['ignore_unknown'] && !(_model['attributes'][name] rescue false))
		    	#(_obj[name]=value)
		    	assign_attributes({name=>value})
		    rescue
		    	puts "Error: could not assign attribute '#{name.to_s}' to element '#{self._tag.to_s}': #{$!}"
		    end
		        
		    def start_el(tag, attributes)		
		    	return if (_model['ignore_unknown'] && !_model['elements'][tag])
		    	
		    	# Set _new_tag for other methods to use during the start_el run.
		    	self._new_tag = tag
		
		    	# Acquire submodel definition.
		      sub = submodel      
		      
		      # Create new element.
		      new_element = (constantize((sub['class']).to_s) || Hash).new
		      #puts "Created new element of class '#{new_element.class}' for tag '#{_tag}'."
		      
		      # Assign attributes to new element.
		      assign_attributes attributes, new_element, sub

					# Attach new element to cursor object
# 					attach_new_object_master(sub, new_element) #unless attributes and !attributes.empty?
					#puts "Attachment lambda for tags #{_tag}:#{_new_tag}";
					cursor = self #.dup
					new_tag = _new_tag
					@attachment_procs << lambda do
						cursor._new_tag = new_tag; cursor.instance_eval {attach_new_object_master(sub, new_element) } #unless attributes and !attributes.empty? }
					end
# 					@attachment_procs.shift(@attachment_procs.size).each{|p| p.call}
		  		
		  		return_tag = _new_tag
		  		self._new_tag = nil
		      return Cursor.new(sub, new_element, return_tag)
		    end # start_el
		
		    def end_el(name)
		      if name == self._tag
		      	@attachment_procs.shift(@attachment_procs.size).each{|p| p.call}
		      	begin
			      	# This is for arrays
			      	_obj.send(_model['before_close'].to_s, self) if _model['before_close']
			      	# This is for hashes with array as value. It may be ilogical in this context. Is it needed?
			      	if _obj.respond_to?('each') && _model['each_before_close']
			      	  _obj.each{|o| o.send(_model['each_before_close'].to_s, _obj)}
		      	  end
			      rescue
			      	puts "Error ending element: #{$!}"
			      end
		        return true
		      end
		    end
		    

		    #####  UTILITY  #####
		
			  def constantize(klass)
			  	self.class.constantize(klass)
			  end
			  
			  def ivg(name, object=_obj); object.instance_variable_get "@#{name}" end
			  def ivs(name, value, object=_obj); object.instance_variable_set "@#{name}", data end
				def submodel(tag=_new_tag); get_submodel(tag) || default_submodel; end
			  def individual_attributes(model=submodel); model['individual_attributes']; end    
			  def hide_attributes(model=submodel); model['hide_attributes']; end
		    def as_attribute(model=submodel); model['as_attribute']; end
		  	def delineate_with_hash(model=submodel); model['delineate_with_hash']; end
		  	def as_label(model=submodel); model['as_label']; end
		  	def label_or_tag; as_label(submodel) || _tag; end
		  	
		  	
	      # Attach new object to current object.
	      def attach_new_object_master(sub, new_element)
	      	puts "Attaching new object '#{_new_tag}:#{new_element.class}' to '#{_tag}:#{sub.class}'"
		      unless sub['hide']
		  			if as_attribute
							merge_with_attributes(as_attribute, new_element)
		    		elsif _obj.is_a?(Hash)
	  					merge_with_hash(label_or_tag, new_element)
		    		elsif _obj.is_a? Array
							merge_with_array(label_or_tag, new_element)
		    		else
		  				merge_with_attributes(label_or_tag, new_element)
		    		end
		      end
		    end
		  	
				def get_submodel(name)
					_model['elements'][name] rescue nil
				end
				
				def default_submodel
					if _model['depth'].to_i > 0
						{'elements' => _model['elements'], 'depth'=>(_model['depth'].to_i - 1)}
					else
						{}
					end
				end
		  	
		  	# Assign attributes to element.
				def assign_attributes(attributes=nil, element=_obj, model=_model)
		      if attributes && !attributes.empty?
		      	(attributes = Hash[attributes]) if attributes.is_a? Array # For nokogiri attributes-as-array
		      	#puts "Assigning attributes: #{attributes.to_a.join(':')}" if attributes.has_key?('text')
		        if element.is_a?(Hash) and !hide_attributes(model)
		        	#puts "Assigning element attributes for '#{element.class}' #{attributes.to_a.join(':')}"
		          element.merge!(attributes)
			      elsif individual_attributes(model)
			      	#puts "Assigning individual attributes for '#{element.class}' #{attributes.to_a.join(':')}"
			        attributes.each{|k, v| set_attr_accessor(k, v, element)}
		        else
		        	#puts "Assigning @att attributes for '#{element.class}' #{attributes.to_a.join(':')}"
			        set_attr_accessor 'att', attributes, element
			      end
		      end
				end
		    
		    def merge_elements(current_element, new_element)
		    	#puts "merge_elements with tags '#{self._tag}/#{label_or_tag}' current_el '#{current_element.class}' and new_el '#{new_element.class}'."
		  	  # TODO: Get rid of this next conditional - may be reason this method isn't working. Sometimes we want a hash, even if there are no delineating fields specified.
		  	  if delineate_with_hash
		  	  	begin
			  	    current_key = get_attribute(delineate_with_hash, current_element)
			  	    new_key = get_attribute(delineate_with_hash, new_element)
			  	    puts "Current-key '#{current_key}', New-key '#{new_key}'"
			  	    unless current_key.to_s.empty? || new_key.to_s.empty?
			  	    	#puts "Merge old-hash-current-element with new-hash"
			  	    	Hash[current_key => current_element].merge(new_key => new_element)
			  	    else
		  	    		current_element.merge(new_key => new_element)
			  	    end
		  	    rescue
		  	    	puts "Error: could not merge with hash: #{$!}" #{[current_key, current_element.class, new_key, new_element.class].join(',')}."
		  	    	([*current_element] << new_element) if current_element.is_a?(Array)
		  	    end
		  	  else
		  	  	[*current_element] << new_element
		    	end
		    end
		    
		    def get_attribute(name, obj=_obj)
		      return obj.att[name] rescue nil
		      return ivg(name, obj) rescue nil
		      return obj[name] rescue nil
		    end
		    
		    def merge_with_attributes(name, element)
  			  if ivg(as_attribute)
					  set_attr_accessor(name, merge_elements(ivg(name), element))
					else
					  set_attr_accessor(as_attribute, element)
				  end
		    end
		    
		    def merge_with_hash(name, element)
    			if _obj[name] #_obj.has_key? name
  					_obj[name] = merge_elements(_obj[name], element)
  			  else			
  	  			_obj[name] = element
    			end
		    end
		    
		    def merge_with_array(name, element)
					if _obj.size > 0
						_obj.replace merge_elements(_obj, element)
					else
  	  			_obj << element
	  			end
		    end
		    
		    def set_attr_accessor(name, data, obj=_obj)
					create_accessor(name, obj)
					obj.instance_eval do
						var = instance_variable_get("@#{name}")
						#puts "Assigning @att attributes for '#{obj.class}' #{data.to_a.join(':')}"
						case
						when data.is_a?(Hash) && var.is_a?(Hash); var.merge!(data)
						when data.is_a?(String) && var.is_a?(String); var << data
						when var.is_a?(Array); [var, data].flatten!
						else instance_variable_set("@#{name}", data)
						end
						#puts "Set element accessor #{name}:#{var.to_a.join(',')}"
						#puts "Element accessor for #{name}:#{self.send(name).to_a.join(',')}"
					end
				end
				#   def set_attr_accessor(name, element, obj=_obj)
				# 		create_accessor(name, obj)
				# 		obj.send "#{name}=", element
				# 	end
								
				def create_accessor(tag, obj=_obj)
					#return unless tag && obj
					obj.class.class_eval do
						attr_accessor "#{tag}"
					end unless obj.instance_variables.include?(":@#{tag}")
				end
		
		end # Cursor
		
		
		
		#####  SAX HANDLER(S)  #####
		
		module Handler
		
			attr_accessor :stack, :grammar
			
			def self.build(io, parser, grammar=nil, initial_object={})
			  (eval(parser.to_s)).build(io, grammar, initial_object)
		  end
		  
		  def self.included(base)
		
		    def base.build(io, grammar=nil, initial_object={})
		  		handler = new(grammar, initial_object)
		  		handler.run_parser(io)
		  		handler.stack[0]._obj
		  	end
		  	
		  	def base.handler
		  		@handler
		  	end
		  end
		  
		  def initialize(grammar=nil, initial_object={})
		  	@stack = []
		  	@grammar = (YAML.load_file(grammar) rescue {})
		  	# Not necessary - for testing only
		  		self.class.instance_variable_set :@handler, self
		    set_cursor Cursor.new(@grammar, initial_object, 'TOP')
		  end
		  
			def cursor
				stack.last
			end
			
			def set_cursor(args) # cursor-object
				if args.is_a? Cursor
					stack.push(args)
					cursor._parent = stack[-2]
					cursor._top = stack[0]
					cursor._stack = stack
				end
				cursor
			end
			
			def dump_cursor
				stack.pop
			end
			
			def transform(name)
				name.to_s.gsub(/\-/, '_')
			end
		
		  # Add a node to an existing element.
			def _start_element(tag, attributes=nil, *args)
				#puts "Receiving element '#{tag}' with attributes '#{attributes}'"
				tag = transform tag
				set_cursor cursor.start_el(tag, attributes)
			end
			
			# Add attribute to existing element.
			def _attribute(name, value, *args)
				#puts "Receiving attribute '#{name}' with value '#{value}'"
				name = transform name
		    cursor.attribute(name,value)
			end
			
			# Add 'content' attribute to existing element.
			def _text(value, *args)
				#puts "Receiving text '#{value}'"
				cursor.attribute('text', value) if value[/[^\s]/]
			end
			
			# Close out an existing element.
			def _end_element(tag, *args)
				tag = transform tag
				#puts "Receiving end_element '#{tag}'"
				cursor.end_el(tag) and dump_cursor
			end
		  
		end # Handler
		
		
		
		#####  SAX PARSER BACKENDS  #####
		
		class OxFmpSax < ::Ox::Sax
		  include Handler
		
		  def run_parser(io)
				case
				when (io.is_a?(File) or io.is_a?(StringIO)); Ox.sax_parse self, io
				when io[/^</]; StringIO.open(io){|f| Ox.sax_parse self, f}
				else File.open(io){|f| Ox.sax_parse self, f}
				end
			end
			
			alias_method :start_element, :_start_element
			alias_method :end_element, :_end_element
			alias_method :attr, :_attribute
			alias_method :text, :_text		  
		end # OxFmpSax


		class RexmlStream
			include REXML::StreamListener
		  include Handler
		
		  def run_parser(io)
		  	parser = REXML::Document
				case
				when (io.is_a?(File) or io.is_a?(StringIO)); parser.parse_stream(io, self)
				when io[/^</]; StringIO.open(io){|f| parser.parse_stream(f, self)}
				else File.open(io){|f| parser.parse_stream(f, self)}
				end
			end
			
			alias_method :tag_start, :_start_element
			alias_method :tag_end, :_end_element
			alias_method :text, :_text
		end # RexmlStream
		
		
		class LibXmlSax
			include LibXML
			include XML::SaxParser::Callbacks
		  include Handler
		
		  def run_parser(io)
				parser = case
					when (io.is_a?(File) or io.is_a?(StringIO)); XML::SaxParser.io(io)
					when io[/^</]; XML::SaxParser.io(StringIO.new(io))
					else XML::SaxParser.io(File.new(io))
				end
				parser.callbacks = self
				parser.parse	
			end
			
			alias_method :on_start_element_ns, :_start_element
			alias_method :on_end_element_ns, :_end_element
			alias_method :on_characters, :_text
		end # LibxmlSax	
		
		class NokogiriSax < Nokogiri::XML::SAX::Document
		  include Handler
		
		  def run_parser(io)
				parser = Nokogiri::XML::SAX::Parser.new(self)	  
				parser.parse(case
					when (io.is_a?(File) or io.is_a?(StringIO)); io
					when io[/^</]; StringIO.new(io)
					else File.new(io)
				end)
			end

			alias_method :start_element, :_start_element
			alias_method :end_element, :_end_element
			alias_method :characters, :_text
		end # NokogiriSax	
		
		
		
		#####  USER MODELS  #####
		
		class FmResultset < Hash
		end
		
		class Datasource < Hash
		end
		
		class Metadata < Array
		end
		
		class Resultset < Array
			def attach_parent_objects(cursor)
				elements = cursor._parent._obj
				elements.each{|k, v| cursor.set_attr_accessor(k, v) unless k == 'resultset'}
				cursor._stack[0] = cursor
			end
		end
		
		class Record < Hash
		end
		
		class Field < Hash
			def build_record_data(cursor)
				#puts "RUNNING Field#build_field_data on record_id:#{cursor._obj['name']}"
				cursor._parent._obj.merge!(cursor._obj['name'] => (cursor._obj['data']['text'] rescue ''))
			end
		end
		
		class RelatedSet < Array
		end
		
		
		
		
		#####  DATA  #####
		DAT = {
			:fm => 'local_testing/resultset.xml',
			:fmp => 'local_testing/resultset_with_portals.xml',
			:xml => 'local_testing/data_fmpxmlresult.xml',
			:xmp => 'local_testing/data_with_portals_fmpxmlresult.xml',
			:lay => 'local_testing/layout.xml',
			:xmd => 'local_testing/db_fmpxmlresult.xml',
			:fmb => 'local_testing/resultset_with_bad_data.xml',
			:sp => 'local_testing/SplashLayout.xml',
			
			:str => StringIO.new(%{
			<top name="top01">
				<middle name="middle01" />
			  <middle name="middle02">
			    <bottom name="bottom01">bottom-text</bottom>
			  </middle>
			  <middle name="middle03">middle03-text</middle>
			</top>
			})
		}

	end # SaxParser
end # Rfm