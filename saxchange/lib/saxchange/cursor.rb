module SaxChange

  # A Cursor instance is created for each element encountered in the parsing run
  # and is where the parsing result is constructed from the custom parsing template.
  # The cursor is the glue between the handler and the resulting object build. The
  # cursor receives input from the handler, loads the corresponding template data,
  # and manipulates the incoming xml data to build the resulting object.
  #
  # Each cursor is added to the stack when its element begins, and removed from
  # the stack when its element ends. The cursor tracks all the important objects
  # necessary to build the resulting object. If you call #cursor on the handler,
  # you will always get the last object added to the stack. Think of a cursor as
  # a framework of tools that accompany each element's build process.
  #
  # NOTE: Methods that change this cursor or its objects should follow the operate-on-this-cursor-only rule.
  class Cursor
    using Refinements
    using ObjectMergeRefinements
    extend Forwardable

    # model - currently active model (rename to current_model)
    # local_model - model of this cursor's tag (rename to local_model)
    # element_attachment_prefs - local object's attachment prefs based on local_model and current_model.
    # level - cursor depth
    attr_accessor :model, :object, :tag, :handler, :xml_parent, :level, :element_attachment_prefs, :new_element_callback, :initial_attributes, :config #, :local_model
    attr_accessor :logical_parent, :logical_parent_model

    def_delegators :handler, :top, :stack

    #singleton_class.extend Forwardable
    #singleton_class.def_delegators Config, :config, :defaults
    
    # We're not using Config module, rolling our own here.
    # Is this really what we want? Why did we do this?
    def self.config
      @config ||= Config.config
    end

    # Main get-constant method
    def self.get_constant(klass, options=config)
      #puts "Getting constant '#{klass.to_s}'"

      case
      when klass.is_a?(Class); klass
        #when (klass=klass.to_s) == ''; DEFAULT_CLASS
      when klass.nil?; options[:default_class]
      when klass == ''; options[:default_class]
      when klass[/::/]; eval(klass)
      when defined?(klass); const_get(klass)  ## == 'constant'; const_get(klass)
        #when defined?(klass); eval(klass) # This was for 'element_handler' pattern.
      else
        SaxChange.log.warn "Could not find constant '#{klass}'"
        options[:default_class]
      end
    end

    # Most if not all cursor settings/attributes should be set at init time.
    def initialize(_tag, _handler, _parent=nil, _initial_attributes=nil, **opts)
      #puts "CURSOR#initialize options: #{opts}"
      @tag     =  _tag
      @handler = _handler
      @config = @handler.config.merge(opts)
      @xml_parent = _parent || self
      @initial_attributes = _initial_attributes
      @level = @xml_parent.level.to_i + 1
      
      ## Experimental for v4
      # Logical_parent is the cursor that has a list of elements that match this element.
      # It could the same as the xml_parent, or it could be somewhere else.
      # The logical_parent may have directives that affect this element or its attributes.
      @logical_parent = logical_parent_search(@tag, @xml_parent)
      @logical_parent_model = @logical_parent&.model
      
      @model = case
      when @tag == '__TOP__'
        @logical_parent_model = @handler.template
      when attach? == 'none'
        @logical_parent.element?(@tag) || config[:default_class].new
      else
        @logical_parent.element?(@tag) || config[:default_class].new
      end
      
      @element_attachment_prefs = compile_attachment_prefs(@logical_parent_model, @model, 'element')
      
      if @element_attachment_prefs.is_a?(Array)
        @new_element_callback = @element_attachment_prefs[1..-1]
        @element_attachment_prefs = @element_attachment_prefs[0]
        @element_attachment_prefs = nil if @element_attachment_prefs.to_s == 'default'
      end
      
      @object = case
      when @tag == '__TOP__'
        @handler.initial_object
      when attach? == 'none'
        # Maybe this needs to be enabled for what used to be attach-cursor?
        build_new_object_from_callback(binding) || config[:default_class].allocate
        #@logical_parent.object
      else
        build_new_object_from_callback(binding) || config[:default_class].allocate
      end

      #puts "\n#{self}.initialize #{@level}-#{@tag}, lg-pnt '#{@logical_parent.tag}', eap '#{@element_attachment_prefs}', nec '#{@new_element_callback}', obj '#{@object.class}', model '#{@model}'"
      self
    end # initialize
    
    # Build a new object, given @new_element_callback and caller_binding.
    def build_new_object_from_callback(caller_binding=binding)
      @new_element_callback ? get_callback(@new_element_callback, caller_binding) : nil
    end

    # Decide how to attach element & attributes associated with this cursor.
    def process_new_element(caller_binding=binding)
      #puts ["\nPROCESS_NEW_ELEMENT tag: #{@tag}", "@element_attachment_prefs: #{@element_attachment_prefs}", "@local_model: #{model}"]

      case
        # when inital cursor, just set model & object.
      when @tag == '__TOP__';
        #puts "__TOP__"
      when @element_attachment_prefs == 'none';
        #puts "__NONE__"
        if @initial_attributes && @initial_attributes.any? #&& @attribute_attachment_prefs != 'none'
          attribute_target.assign_attributes(@initial_attributes, @model)
        end
      else
        #puts "__OTHER__"

        if @initial_attributes && @initial_attributes.any? #&& @attribute_attachment_prefs != 'none'
          #puts "PROCESS_NEW_ELEMENT calling assign_attributes with ATTRIBUTES #{@initial_attributes}"
          attribute_target.assign_attributes(@initial_attributes, @model) #, @object, @model, @local_model) 
        end

        # If @model has a delimiter, defer attach_new_element until later.
        #puts "PROCESS_NEW_ELEMENT delimiter of @model #{delimiter?(@model)}"
        if !delimiter?(@model) 
          #attach_new_object(@parent.object, @object, @tag, @parent.model, @local_model, 'element')
          #puts "PROCESS_NEW_ELEMENT calling attach_new_element with TAG #{@tag} and OBJECT #{@object}"
          @logical_parent.attach_new_element(@tag, @object, self)
        end      
      end # case

      self
    end # process_new_element


    #####  SAX METHODS  #####

    # Receive a single attribute (any named attribute or text)
    def receive_attribute(name, value)
      #puts ["\nRECEIVE_ATTR '#{name}'", "value: #{value}", "tag: #{@tag}", "object: #{object.class}", "model: #{model['name']}"]
      new_att = {name=>value}    #.new.tap{|att| att[name]=value}
      # Temp disable for v4.
      attribute_target.assign_attributes(new_att, @model) #, @object, @model, @local_model)
    rescue
      SaxChange.log.warn "Error: could not assign attribute '#{name.to_s}' to element '#{self.tag.to_s}': #{$!}"
    end

    def receive_start_element(_tag, _attributes)
      #puts "Cursor for #{tag} receiveing start_element for #{_tag}"
      #puts ["\nRECEIVE_START '#{_tag}'", "current_object: #{@object.class}", "current_model: #{@model['name']}", "attributes #{_attributes}"]
      new_cursor = Cursor.new(_tag, @handler, self, _attributes, **@config) #, binding)
      new_cursor.process_new_element(binding)
      new_cursor
    end # receive_start_element

    def receive_end_element(_tag)
      #puts ["\nRECEIVE_END_ELEMENT '#{_tag}'", "tag: #{@tag}", "object: #{@object.class}", "model: #{@model['name']}", "local_model: #{@local_model['name']}"]
      #puts ["\nEND_ELEMENT_OBJECT", object.to_yaml]
      begin

        if _tag == @tag && (@model == @logical_parent_model)
          # Data cleaup
          compactor_settings = compact? || compact_default?
          #(compactor_settings = compact?(top.model)) unless compactor_settings # prefer local settings, or use top settings.
          (clean_members {|v| clean_members(v){|w| clean_members(w)}}) if compactor_settings
        end

        if (delimiter = delimiter?(@model); delimiter && !['none','cursor'].include?(@element_attachment_prefs.to_s))
          #attach_new_object(@parent.object, @object, @tag, @parent.model, @local_model, 'element')
          #puts "RECEIVE_END_ELEMENT attaching new element TAG (#{@tag}) OBJECT (#{@object.class}) #{@object.to_yaml} WITH LOCAL MODEL #{@local_model.to_yaml} TO PARENT (#{@parent.object.class}) #{@parent.object.to_yaml} PARENT MODEL #{@parent.model.to_yaml}"
          @logical_parent.attach_new_element(@tag, @object, self)
        end      

        if _tag == @tag #&& (@model == @local_model)
          # End-element callbacks.
          #run_callback(_tag, self)
          callback = before_close?(@model)
          get_callback(callback, binding) if callback
        end

        if _tag == @tag
          # return true only if matching tags
          return true
        end

        return
        # TODO: Dunno how long this has been commented out.
        #       If it's not used, remove the begin/end keywords.
        #           rescue
        #            SaxChange.log.debug "Error: end_element tag '#{_tag}' failed: #{$!}"
      end # begin
    end # receive_end_element


    #####  MERGE METHODS  #####

    # Assign attributes to this cursor's object.
    # The attributes could be from this element or from any sub-element.
    def assign_attributes(_attributes, attributes_element_model=@model)
      if _attributes && !_attributes.empty?

        _attributes.each do |k,v|
          attr_model = attribute?(k, attributes_element_model)
          #puts "\nASSIGN_ATTRIBUTES each attr key:#{k}, val:#{v}, attr_model:#{attr_model}, @model:#{@model}"

          label = label_or_tag(k, attr_model)

          # TODO: for v4, does this @model need to be @logical_parent_model? NO.
          # Gets compiled prefs from local-attr-attachment-prefs and attribute-specific-model
          prefs = [compile_attachment_prefs(@model, attr_model, 'attribute')].flatten(1)[0]
          #puts "ASSIGN_ATTRIBUTES to @model: #{@model}"
          #puts "ASSIGN_ATTRIBUTES with compiled prefs: #{prefs}"

          shared_var_name = shared_variable_name(prefs)
          (prefs = "shared") if shared_var_name

          # TODO: for v4, does this @model need to be @logical_parent_model? NO
          # Use local create_accessors prefs first, then more general ones.
          #create_accessors = accessor?(attr_model) || create_accessors?(@model)
          create_accessors = compile_create_accessors(@model, attr_model)
          #(create_accessors = create_accessors?(@model)) unless create_accessors && create_accessors.any?

          #puts ["\nASSIGN_ATTRIBUTES-attach-object", "label: #{label}", "object-class: #{@object.class}", "k,v: #{[k,v]}", "attr_model: #{attr_model}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]
          @object._attach_object!(v, label, delimiter?(attr_model), prefs, 'attribute', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
        end

      end
    end # assign_attributes

    # This ~should~ be only concerned with how to attach a given element to THIS cursor's object.
    def attach_new_element(name, new_object, new_object_cursor) 
      label = label_or_tag(name, new_object_cursor.model)

      # Was this, which works fine, but not as efficient:
      # prefs = [attachment_prefs(base_model, new_model, type)].flatten(1)[0]
      #prefs = attachment_prefs(@model, new_object_cursor.model, 'element') #@element_attachment_prefs
      prefs = new_object_cursor.element_attachment_prefs

      shared_var_name = shared_variable_name(prefs)
      (prefs = "shared") if shared_var_name

      # Use element's specific accessors? prefs first, then use more general create_accessors? from element's logical_parent (this cursor).
      # Mods for v4.
      #create_accessors = accessor?(@local_model) || create_accessors?(@parent.model)
      #create_accessors = accessor?(new_object_cursor.model) || create_accessors?(@model)
      create_accessors = compile_create_accessors(@model, new_object_cursor.model)
      #(create_accessors = create_accessors?(@parent.model)) unless create_accessors && create_accessors.any?

      # NOTE: This has been disabled for a long time.
      # # This is NEW!
      # translator = new_model['translator']
      # if translator
      #   new_object = base_object.send translator, name, new_object
      # end


      #puts ["\nATTACH_NEW_ELEMENT 1", "new_object: #{new_object}", "parent_object: #{@object}", "label: #{name}", "delimiter: #{delimiter?(new_object_model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}", "default_class: #{config[:default_class]}"]
      
      # Mods for v4.
      #@parent.object._attach_object!(new_object, label, delimiter?(@local_model), prefs, 'element', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
      #@logical_parent.object._attach_object!(new_object, label, delimiter?(@model), prefs, 'element', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
      object._attach_object!(new_object, label, delimiter?(new_object_cursor.model), prefs, 'element', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
      
      # if type == 'attribute'
      #   puts ["\nATTACH_ATTR", "name: #{name}", "label: #{label}", "new_object: #{new_object.class rescue ''}", "base_object: #{base_object.class rescue ''}", "base_model: #{base_model['name'] rescue ''}", "new_model: #{new_model['name'] rescue ''}", "prefs: #{prefs}"]
      # end
    end # attach_new_element


    #####  UTILITY  #####

    # Methods to extract template delcarations from current @model.
    # These could also be applied to any given model, even an attribute-model.
    ###
    ### Not Used ?
    ###
    def ivg(name, _object=@object); _object.instance_variable_get "@#{name}"; end
    def ivs(name, value, _object=@object); _object.instance_variable_set "@#{name}", value; end
    def initialize_with?(_model=@model); _model&.dig('initialize_with'); end
    def each_before_close?(_model=@model); _model&.dig('each_before_close'); end
    def depth?(_model=@model); _model&.dig('depth'); end
    def element_handler?(_model=@model); _model&.dig('element_handler'); end
    ###
    ### Defaults for All Cursors/Models
    ###
    def attach_elements_default?; top&.model&.dig('attach_elements_default'); end
    def attach_attributes_default?; top&.model&.dig('attach_attributes_default'); end
    def compact_default?; top&.model&.dig('compact'); end
    def create_accessors_default?; top&.model&.dig('create_accessors_default') && [top&.model&.dig('create_accessors_default')].flatten.compact; end
    ###
    ### For This (or specified) Cursor Only
    ###
    def elements?(_model=@model); _model&.dig('elements'); end
    def attributes?(_model=@model); _model&.dig('attributes'); end
    def element?(_tag=@tag, _model=@model) _model&.dig('elements')&.find{|e| e&.dig('name') == _tag}; end
    def attribute?(_tag=@tag, _model=@model) _model&.dig('attributes')&.find{|e| e&.dig('name') == _tag}; end
    def before_close?(_model=@model); _model&.dig('before_close'); end
    def compact?(_model=@model); _model&.dig('compact'); end
    def attach?(_model=@model); _model&.dig('attach'); end
    def attach_elements?(_model=@model); _model&.dig('attach_elements'); end
    def attach_attributes?(_model=@model); _model&.dig('attach_attributes'); end
    def delimiter?(_model=@model); _model&.dig('delimiter'); end
    def as_name?(_model=@model); _model&.dig('as_name'); end
    def create_accessors?(_model=@model); _model&.dig('create_accessors') && [_model&.dig('create_accessors')].flatten.compact; end
    def accessor?(_model=@model); _model&.dig('accessor') && [_model&.dig('accessor')].flatten.compact; end


    ###  Parse callback instructions, compile & send callback method  ###
    ###  TODO: This is way too convoluted. Document it better, or refactor!!!
    # This method will send a method to an object, with parameters, and return a new object.
    # Input (first param): string, symbol, or array of strings
    # Returns: object
    # Default options:
    #   :object=>object
    #   :method=>'a method name string or symbol'
    #   :params=>"params string to be eval'd in context of cursor"
    # Usage:
    #   callback: send a method (or eval string) to an object with parameters, consisting of...
    #     string: a string to be eval'd in context of current object.
    #     or symbol: method to be called on current object.
    #     or array: object, method, params.
    #       object: <object or string>
    #       method: <string or symbol>
    #       params: <string>
    #
    # TODO-MAYBE: Change param order to (method, object, params),
    #             might help confusion with param complexities.
    #
    def get_callback(callback, caller_binding=binding, _defaults={})
      input = callback.is_a?(Array) ? callback.dup : callback
      #puts "\nGET_CALLBACK tag: #{tag}, callback: #{callback}"
      params = case
               when input.is_a?(String) || input.is_a?(Symbol)
                 [nil, input]
                 # when input.is_a?(Symbol)
                 #   [nil, input]
               when input.is_a?(Array)
                 #puts ["\nCURSOR#get_callback is an array", input]
                 case
                 when input[0].is_a?(Symbol)
                   [nil, input].flatten(1)
                 when input[1].is_a?(String) && ( input.size > 2 || (remove_colon=(input[1][0,1]==":"); remove_colon) )
                   code_or_method = input[1].dup
                   code_or_method[0]='' if remove_colon
                   code_or_method = code_or_method.to_sym
                   output = [input[0], code_or_method, input[2..-1]].flatten(1)
                   #puts ["\nCURSOR#get_callback converted input[1] to symbol", output]
                   output
                 else # when input is ['object', 'sym-or-str', 'param1',' param2', ...]
                   input
                 end
               else
                 []
               end

      obj_raw = params.shift
      #puts ["\nOBJECT_RAW:","class: #{obj_raw.class}", "object: #{obj_raw}"]
      obj = if obj_raw.is_a?(String)
              eval(obj_raw.to_s, caller_binding)
            else
              obj_raw
            end
      if obj.nil? || obj == ''
        obj = _defaults[:object] || @object
      end
      #puts ["\nOBJECT:","class: #{obj.class}", "object: #{obj}"]

      code = params.shift || _defaults[:method]
      params.each_with_index do |str, i|
        if str.is_a?(String)
          params[i] = eval(str, caller_binding)
        end
      end
      params = _defaults[:params] if params.size == 0
      #puts ["\nGET_CALLBACK tag: #{@tag}" ,"callback: #{callback}", "obj.class: #{obj.class}", "code: #{code}", "params-class #{params.class}"]
      case
      when (code.nil? || code=='')
        obj
      when (code.is_a?(Symbol) || params)
        #puts ["\nGET_CALLBACK sending symbol", obj.class, code] 
        obj.send(*[code, params].flatten(1).compact)
      when code.is_a?(String)
        #puts ["\nGET_CALLBACK evaling string", obj.class, code]
        obj.send :eval, code
        #eval(code, caller_binding)
      end          
    end # get_callback


    # Which cursor to attach this element's attributes to.
    def attribute_target
      if @model&.dig('attach') == 'none'
        @logical_parent
      else
        self
      end
    end

    # This should be called within the target, when it is about to attach an incoming object.
    # NOTE: The top.model defaults option is new for v4 (it was disabled before)
    def compile_attachment_prefs(target_model, new_model, type)
      case type
      when 'element'; attach?(new_model) || attach_elements?(target_model) || attach_elements_default?
      when 'attribute'; attach?(new_model) || attach_attributes?(target_model) || attach_attributes_default?
      end
    end
    
    def compile_create_accessors(_parent_model, _local_model)
      create_accessors = accessor?(_local_model) || create_accessors?(_parent_model) || create_accessors_default?
    end

    # Get shared variable name from element attachment prefs, if any.
    def shared_variable_name(prefs)
      rslt = nil
      if prefs.to_s[0,1] == "_"
        rslt = prefs.to_s[1..-1] #prefs.gsub(/^_/, '')
      end
    end

    def get_constant(klass)
      self.class.get_constant(klass, config)
    end

    # Get the tag name or corresponding 'as_name?'
    def label_or_tag(_tag=@tag, _model=@model); as_name?(_model) || _tag; end

    # I know this is important... but what does it do?
    def clean_members(obj=@object)
      #puts ["CURSOR.clean_members: #{object.class}", "tag: #{tag}", "model-name: #{model[:name]}"]
      #   cursor.object = clean_member(cursor.object)
      #   clean_members(ivg(shared_attribute_var, obj))
      if obj.is_a?(Hash)
        obj.dup.each do |k,v|
          obj[k] = clean_member(v)
          yield(v) if block_given?
        end
      elsif obj.is_a?(Array)
        obj.dup.each_with_index do |v,i|
          obj[i] = clean_member(v)
          yield(v) if block_given?
        end
      else  
        obj.instance_variables.each do |var|
          dat = obj.instance_variable_get(var)
          obj.instance_variable_set(var, clean_member(dat))
          yield(dat) if block_given?
        end
      end
      #   obj.instance_variables.each do |var|
      #     dat = obj.instance_variable_get(var)
      #     obj.instance_variable_set(var, clean_member(dat))
      #     yield(dat) if block_given?
      #   end
    end

    def clean_member(val)
      if val.is_a?(Hash) || val.is_a?(Array); 
        if val && val.empty?
          nil
        elsif val && val.respond_to?(:values) && val.size == 1
          val.values[0]
        else
          val
        end
      else
        val
        #   # Probably shouldn't do this on instance-var values. ...Why not?
        #     if val.instance_variables.size < 1
        #       nil
        #     elsif val.instance_variables.size == 1
        #       val.instance_variable_get(val.instance_variables[0])
        #     else
        #       val
        #     end
      end
    end # clean_member
    
    
    ##  New for v4. Note that these methods, while potentially functional,
    ##  may also be very rough around the edges.
    
    ##  Logical parent is the first ancestor whose element list has a match for this element.
    ##  If no matching ancestor, the logical parent is the xml parent.

    # Find cursor xml ancestors (parent of parent of...)
    def xml_ancestors
      return [self] if level <= 1
      [self].concat xml_parent.xml_ancestors
    end
    
    # Find cursor logical ancestors (logical_parent of logical_parent of...)
    def logical_ancestors
      return [self] if level <= 1
      [self].concat logical_parent.logical_ancestors
    end

    # Compile all possible ancestors of this cursor into a uniq array,
    # before searching each one for matching elements.
    # Return the cursor with an element defined for _tag.
    def logical_parent_search(_tag=@tag, _starting_cursor=@xml_parent)
      ancestors = _starting_cursor.xml_ancestors | _starting_cursor.logical_ancestors
      uniq_ancestors = ancestors.map{|a| [a, a.xml_parent, a.logical_parent]}.flatten.compact.uniq.sort{|a,b| a.level <=> b.level}.reverse
      #puts uniq_ancestors.map(&:tag).join(', ') # This is shorthand for map{|a| a&.tag}.join(', '), but what will it do if a==nil?
      
      uniq_ancestors.find{|a| a.model&.dig('elements')&.find{|e| e['name'] == _tag} } ||
      uniq_ancestors.find{|a| a.model&.dig('attach') != 'none'} ||
      top
    end

  end # Cursor
end # SaxChange