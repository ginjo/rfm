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
    attr_accessor :model, :object, :tag, :handler, :xml_parent, :level, :element_attachment_prefs, :new_element_callback, :initial_attributes
    attr_accessor :logical_parent, :logical_parent_model  #, :initial_object

    def_delegators :handler, :top, :stack, :config


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
    def initialize(_tag, _handler, _parent=nil, _initial_attributes=nil)  #, **opts)
      #puts "CURSOR#initialize hnd: #{_handler}"
      @tag     =  _tag
      @handler = _handler
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
      # NOTE: '=' takes precedence over 'if', so you don't need parens around assignment expression.
      # TODO: Should this go further down the chain, maybe in the object-merge methods?
      @element_attachment_prefs = nil if @element_attachment_prefs.to_s == 'default'
      
      @object = case
        when @tag == '__TOP__'
          @handler.initial_object
        #when attach? == 'none'
        #
        else
          get_initial_object(binding)
      end

      #puts "\n#{self}.initialize #{@level}-#{@tag}, lg-pnt '#{@logical_parent.tag}', eap '#{@element_attachment_prefs}', obj '#{@object.class}', model '#{@model['name']}'"
      self
    end # initialize
    
    def get_initial_object(env_binding=binding)
      initobj = initial_object?(@model)
      rslt = case
      when initobj.is_a?(Class); initobj.new
      when initobj.is_a?(Proc); instance_exec(env_binding, &initobj)
      else initobj || config[:default_class].allocate
      end
      #puts "Cursor#compile_initial_object with '#{initobj}', rslt '#{rslt}'"
      rslt
    end

    def process_new_element(caller_binding=binding)
      #puts ["\nPROCESS_NEW_ELEMENT tag: #{@tag}", "@element_attachment_prefs: #{@element_attachment_prefs}", "@local_model: #{model}"]
      return self if @tag == '__TOP__'
      
      attribute_target.assign_attributes(@initial_attributes, @model) if @initial_attributes&.any?
      
      # if ! ['none', 'hidden'].include?(@element_attachment_prefs) &&
      #    ! @element_attachment_prefs.is_a?(Proc) &&
      #    ! delimiter?
      # then
      #   @logical_parent.attach_new_element(@tag, @object, self)
      # end

      self
    end # process_new_element



    #####  MERGE METHODS  #####

    # Assign attributes to this cursor's object.
    # The attributes could be from this element or from any sub-element.
    # TODO: Figure out a way to run attribute-attachment procs in origin cursor,
    #       rather than here, in target cursor.
    def assign_attributes(_attributes, attributes_element_model=@model)
      if _attributes && !_attributes.empty?

        _attributes.each do |k,v|
          attr_model = attribute?(k, attributes_element_model)
          #puts "\nASSIGN_ATTRIBUTES each attr key:#{k}, val:#{v}, attr_model:#{attr_model}, @model:#{@model}"

          label = label_or_tag(k, attr_model)

          prefs = compile_attachment_prefs(@model, attr_model, 'attribute')

          shared_var_name = shared_variable_name(prefs)
          
          prefs = "shared" if shared_var_name

          create_accessors = compile_create_accessors(@model, attr_model)

          proc_result = instance_exec(binding, &prefs) if prefs.is_a?(Proc)
          prefs = proc_result if proc_result

          #puts ["\nASSIGN_ATTRIBUTES-attach-object", "label: #{label}", "receiving-object-class: #{@object.class}", "k,v: #{[k,v]}", "attr_model: #{attr_model}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}", "delimiter: #{delimiter?(attr_model)}"]

          if proc_result || !prefs.is_a?(Proc)
            @object._attach_object!(v, label, delimiter?(attr_model), prefs, 'attribute', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
          end
        end

      end # if
    end # assign_attributes

    # This ~should~ be only concerned with how to attach a given element to THIS cursor's object.
    # TODO: Reconsider the args passed to this method. I think get rid of arg 'new_object'.
    #     def attach_new_element(name, new_object, new_object_cursor) 
    #       label = label_or_tag(name, new_object_cursor.model)
    # 
    #       prefs = new_object_cursor.element_attachment_prefs
    # 
    #       shared_var_name = shared_variable_name(prefs)
    # 
    #       prefs = "shared" if shared_var_name
    # 
    #       create_accessors = compile_create_accessors(@model, new_object_cursor.model)
    # 
    #       proc_result = new_object_cursor.instance_exec(binding, &prefs) if prefs.is_a?(Proc)
    #       
    #       prefs = proc_result if proc_result
    # 
    #       #puts ["\nATTACH_NEW_ELEMENT", "new_object: #{new_object}", "parent_object: #{@object}", "label: #{name}", "delimiter: #{delimiter?(new_object_cursor.model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]      
    #       
    #       if proc_result || !prefs.is_a?(Proc)
    #         @object._attach_object!(new_object, label, delimiter?(new_object_cursor.model), prefs, 'element', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
    #       end
    #     end # attach_new_element

    def attach_new_element(name, new_object, new_object_model, prefs) 
      label = label_or_tag(name, new_object_model)

      #prefs = new_object_cursor.element_attachment_prefs
      #prefs = compile_attachment_prefs(@model, new_object_model, 'element')

      # Should this mutation happen later down the line,
      # at the last possible point before it's needed?
      # Maybe this is that point?
      shared_var_name = shared_variable_name(prefs)
      prefs = "shared" if shared_var_name

      create_accessors = compile_create_accessors(@model, new_object_model)      

      #puts ["\nATTACH_NEW_ELEMENT", "new_object: #{new_object}", "parent_object: #{@object}", "label: #{name}", "delimiter: #{delimiter?(new_object_cursor.model)}", "prefs: #{prefs}", "shared_var_name: #{shared_var_name}", "create_accessors: #{create_accessors}"]      
      
      @object._attach_object!(new_object, label, delimiter?(new_object_model), prefs, 'element', :default_class=>config[:default_class], :shared_variable_name=>shared_var_name, :create_accessors=>create_accessors)
    end # attach_new_element



    #####  SAX METHODS  #####

    # Receive a single attribute (any named attribute or text)
    def receive_attribute(name, value)
      #puts ["\nRECEIVE_ATTR '#{name}'", "value: #{value}", "tag: #{@tag}", "object: #{object.class}", "model: #{model['name']}"]
      new_att = {name=>value}
      attribute_target.assign_attributes(new_att, @model)
    rescue
      SaxChange.log.warn "Error: could not assign attribute '#{name.to_s}' to element '#{self.tag.to_s}': #{$!}"
    end

    def receive_start_element(_tag, _attributes)
      #puts "Cursor for #{tag} receiveing start_element for #{_tag}"
      #puts ["\nRECEIVE_START '#{_tag}'", "current_object: #{@object.class}", "current_model: #{@model['name']}", "attributes #{_attributes}"]
      #new_cursor = Cursor.new(_tag, @handler, self, _attributes, **@config) #, binding)
      new_cursor = Cursor.new(_tag, @handler, self, _attributes)
      new_cursor.process_new_element(binding)
      new_cursor
    end # receive_start_element

    def receive_end_element(_tag)
      #puts ["\nRECEIVE_END_ELEMENT '#{_tag}'", "tag: #{@tag}", "object: #{@object.class}", "model: #{@model}"]
      #puts ["\nEND_ELEMENT_OBJECT", object.to_yaml]
      begin

        if _tag == @tag && (@model == @logical_parent_model)
          # Data cleanup
          compactor_settings = compact? || compact_default?
          #(compactor_settings = compact?(top.model)) unless compactor_settings # prefer local settings, or use top settings.
          #puts "Cursor#receive_end_element compactor_settings '#{compactor_settings}'"
          (clean_members {|v| clean_members(v){|w| clean_members(w)}}) if compactor_settings
        end
        
        prefs = @element_attachment_prefs
        #if (delimiter = delimiter?(@model); delimiter && !['none','hidden'].include?(@element_attachment_prefs.to_s)) || @element_attachment_prefs.is_a?(Proc)
        if prefs.is_a?(Proc)
          proc_result = instance_exec(binding, &prefs)
          prefs = proc_result if proc_result
        end
        
        if ! ['none', 'hidden'].include?(prefs)
          #puts "RECEIVE_END_ELEMENT attaching new element TAG (#{@tag}) OBJECT (#{@object.class}) #{@object.to_yaml} WITH LOCAL MODEL #{@local_model.to_yaml} TO PARENT (#{@parent.object.class}) #{@parent.object.to_yaml} PARENT MODEL #{@parent.model.to_yaml}"
          #@logical_parent.attach_new_element(@tag, @object, self)
          @logical_parent.attach_new_element(@tag, @object, @model, prefs)
        end      

        if _tag == @tag #&& (@model == @local_model)
          #puts "Cursor#receive_end_element before-close-callback"
          callback = before_close?(@model)
          instance_exec(binding, &callback) if callback.is_a?(Proc)
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


    #####  UTILITY  #####
    
    # TODO: Special setting names (like 'none', 'shared', 'private') should be
    #       symbols, not strings.
    # TODO: Should probably wait until element_close to attach elements.
    #       This shouldn't affect attribute and sub-element attachment, and might
    #       reduce complexity of attachment logic.
    # TODO: Consider adding optional callbacks for (after-new-element, before/after-attribute, before/after-element-close).
    

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
    def create_accessors_default?; [top&.model&.dig('create_accessors_default')].flatten.compact.as{|i| i.any? && i}; end
    ###
    ### For This (or specified) Cursor Only
    ###
    def initial_object?(_model=@model); _model&.dig('initial_object'); end
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
    def create_accessors?(_model=@model); [_model&.dig('create_accessors')].flatten.compact.as{|i| i.any? && i}; end
    def accessor?(_model=@model); [_model&.dig('accessor')].flatten.compact.as{|i| i.any? && i}; end


    # Which cursor to attach this element's attributes to.
    # TODO: This needs work.
    # What does an element with attach:none do with attributes?
    def attribute_target
      @attribute_target ||=
      #if attach? == 'none' && (attach_attributes? == 'none' || attach_attributes?.nil?)
      # This changes to general rule that "attach:none disables this cursor's attach_attributes affect".
      # This now says that when attach:none, attributes will by-default 'skip' to attach to parent,
      # unless attach_attributes is something other than nil or 'skip'.
      if attach? == 'none' && attach_attributes?.nil? || attach_attributes? == 'skip'
      #if @element_attachment_prefs == 'none' && attach_attributes?.nil? || attach_attributes? == 'skip'
        #puts "Getting Attribute Target for '#{@tag}', with l-p '#{@logical_parent&.tag}', self '#{self.class}', top '#{top}', handler '#{handler.class}'"
        @logical_parent&.attribute_target || top
      else
        self
      end
    end
    
    # This should be called within the target, when it is about to attach an incoming object.
    # NOTE: The top.model defaults option is new for v4 (it was disabled before)
    def compile_attachment_prefs(target_model, new_model, type)
      prefs = case type
      when 'element'; attach?(new_model) || attach_elements?(target_model) || attach_elements_default?
      when 'attribute'; attach?(new_model) || attach_attributes?(target_model) || attach_attributes_default?
      end
      prefs
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
      
      # uniq_ancestors.find{|a| a.model&.dig('elements')&.find{|e| e['name'] == _tag} } ||
      # uniq_ancestors.find{|a| a.model&.dig('attach') != 'none' } ||
      uniq_ancestors.find{|a| a.elements?&.find{|e| e['name'] == _tag} } ||
      #uniq_ancestors.find{|a| a.attach? != 'none' } ||
      # This is same logic as attribute_target above, but the truth is reversed.
      # "This now says that when attach:none, l-p will by-default 'skip' to the next higher parent,
      # unless attach_elements is something other than nil or 'skip'.
      # This says skip the cursor if attach_elements:skip, or if attach_elements is empty and attach:none.
      # It also means if attach:none && attach_elements:none, then use this cursor as l-p, but don't attach any elements to it.
      # Experimentally, trying out attach:skip should be same as previous attach:cursor.
      uniq_ancestors.find{|a| ! (a.attach? == 'none' && a.attach_elements?.nil? || a.attach_elements? == 'skip') } ||
      # This shouldn't work, since @element_attachment_prefs hasn't been set yet!
      #uniq_ancestors.find{|a| ! (a.element_attachment_prefs == 'none' && a.attach_elements?.nil? || a.attach_elements? == 'skip') } ||  # || a.attach? == 'skip') } ||
      top
    end

  end # Cursor
end # SaxChange