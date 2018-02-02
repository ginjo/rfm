module ObjectMergeRefinements

  refine Object do
  
    # Master method to attach any object to this object.
    def _attach_object!(obj, *args) # name/label, collision-delimiter, attachment-prefs, type, *options: <options>
      #puts ["\nATTACH_OBJECT._attach_object", "self.class: #{self.class}", "obj.class: #{obj.class}", "obj.to_s: #{obj.to_s}", "args: #{args}"]
      options = ATTACH_OBJECT_DEFAULT_OPTIONS.merge(args.last.is_a?(Hash) ? args.pop : {}){|key, old, new| new || old}
      #   name = (args[0] || options[:name])
      #   delimiter = (args[1] || options[:delimiter])
      prefs = (args[2] || options[:prefs])
      #   type = (args[3] || options[:type])
      return if ['cursor','none','skip'].include?(prefs)  #=='none' || prefs=='cursor')   #['none', 'cursor'].include? prefs ... not sure which is faster.
      self._merge_object!(
        obj,
        args[0] || options[:name] || 'unknown_name',
        args[1] || options[:delimiter],
        prefs,
        args[3] || options[:type],
        options
      )
  
      #     case
      #     when prefs=='none' || prefs=='cursor'; nil
      #     when name
      #       self._merge_object!(obj, name, delimiter, prefs, type, options)
      #     else
      #       self._merge_object!(obj, 'unknown_name', delimiter, prefs, type, options)
      #     end
      #puts ["\nATTACH_OBJECT RESULT", self.to_yaml]
      #puts ["\nATTACH_OBJECT RESULT PORTALS", (self.portals.to_yaml rescue 'no portals')]
    end
  
    # Master method to merge any object with this object
    def _merge_object!(obj, name, delimiter, prefs, type, options={})
      #puts ["\n-----OBJECT._merge_object", self.class, (obj.to_s rescue obj.class), name, delimiter, prefs, type.capitalize, options].join(', ')
      if prefs=='private'
        _merge_instance!(obj, name, delimiter, prefs, type, options)
      else
        _merge_shared!(obj, name, delimiter, prefs, type, options)
      end
    end
  
    # Merge a named object with the shared instance variable of self.
    def _merge_shared!(obj, name, delimiter, prefs, type, options={})
      shared_var = instance_variable_get("@#{options[:shared_variable_name]}") || instance_variable_set("@#{options[:shared_variable_name]}", options[:default_class].new)
      #puts "\n-----OBJECT._merge_shared: self '#{self.class}' obj '#{obj.class}' name '#{name}' delimiter '#{delimiter}' type '#{type}' shared_var '#{options[:shared_variable_name]} - #{shared_var.class}'"
      # TODO: Figure this part out:
      # The resetting of shared_variable_name to 'attributes' was to fix Asset.field_controls (it was not able to find the valuelive name).
      # I think there might be a level of hierarchy that is without a proper cursor model, when using shared variables & object delimiters.
      shared_var._merge_object!(obj, name, delimiter, nil, type, options.merge(:shared_variable_name=>ATTACH_OBJECT_DEFAULT_OPTIONS[:shared_variable_name]))
    end
  
    # Merge a named object with the specified instance variable of self.
    def _merge_instance!(obj, name, delimiter, prefs, type, options={})
      #puts ["\nOBJECT._merge_instance!", "self.class: #{self.class}", "obj.class: #{obj.class}", "name: #{name}", "delimiter: #{delimiter}", "prefs: #{prefs}", "type: #{type}", "options.keys: #{options.keys}", '_end_merge_instance!']  #.join(', ')
      rslt = if instance_variable_get("@#{name}") || delimiter
               if delimiter
                 delimit_name = obj._get_attribute(delimiter, options[:shared_variable_name]).to_s.downcase
                 #puts ["\n_setting_with_delimiter", delimit_name]
                 #instance_variable_set("@#{name}", instance_variable_get("@#{name}") || options[:default_class].new)[delimit_name]=obj
                 # This line is more efficient than the above line.
                 instance_variable_set("@#{name}", options[:default_class].new) unless instance_variable_get("@#{name}")
  
                 # This line was active in 3.0.9.pre01, but it was inserting each portal array as an element in the array,
                 # after all the SaxChange::Record instances had been added. This was causing an potential infinite recursion situation.
                 # I don't think this line was supposed to be here - was probably an older piece of code.
                 #instance_variable_get("@#{name}")[delimit_name]=obj
  
                 #instance_variable_get("@#{name}")._merge_object!(obj, delimit_name, nil, nil, nil)
                 # Trying to handle multiple portals with same table-occurance on same layout.
                 # In parsing terms, this is trying to handle multiple elements who's delimiter field contains the SAME delimiter data.
                 instance_variable_get("@#{name}")._merge_delimited_object!(obj, delimit_name)
               else
                 #puts ["\_setting_existing_instance_var", name]
                 if name == options[:text_label]
                   instance_variable_get("@#{name}") << obj.to_s
                 else
                   instance_variable_set("@#{name}", [instance_variable_get("@#{name}")].flatten << obj)
                 end
               end
             else
               #puts ["\n_setting_new_instance_var", name]
               instance_variable_set("@#{name}", obj)
             end
  
      # NEW
      _create_accessor(name) if (options[:create_accessors] & ['all','private']).any?
  
      rslt
    end
  
    def _merge_delimited_object!(obj, delimit_name)
      #puts "MERGING DELIMITED OBJECT self #{self.class} obj #{obj.class} delimit_name #{delimit_name}"
  
      case
      when self[delimit_name].nil?; self[delimit_name] = obj
      when self[delimit_name].is_a?(Hash); self[delimit_name].merge!(obj)
      when self[delimit_name].is_a?(Array); self[delimit_name] << obj
      else self[delimit_name] = [self[delimit_name], obj]
      end
    end
  
    # Get an instance variable, a member of a shared instance variable, or a hash value of self.
    def _get_attribute(name, shared_var_name=nil, options={})
      return unless name
      #puts ["\n\n", self.to_yaml]
      #puts ["OBJECT_get_attribute", self.class, self.instance_variables, name, shared_var_name, options].join(', ')
      (shared_var_name = options[:shared_variable_name]) unless shared_var_name
  
      rslt = case
             when self.is_a?(Hash) && self[name]; self[name]
             when ((var= instance_variable_get("@#{shared_var_name}")) && var[name]); var[name]
             else instance_variable_get("@#{name}")
             end
  
      #puts "OBJECT#_get_attribute: name '#{name}' shared_var_name '#{shared_var_name}' options '#{options}' rslt '#{rslt}'"
      rslt
    end
  
    #   # We don't know which attributes are shared, so this isn't really accurate per the options.
    #   # But this could be useful for mass-attachment of a set of attributes (to increase performance in some situations).
    #   def _create_accessors options=[]
    #     options=[options].flatten.compact
    #     #puts ['CREATE_ACCESSORS', self.class, options, ""]
    #     return false if (options & ['none']).any?
    #     if (options & ['all', 'private']).any?
    #       meta = (class << self; self; end)
    #       meta.send(:attr_reader, *instance_variables.collect{|v| v.to_s[1,99].to_sym})
    #     end
    #     if (options & ['all', 'shared']).any?
    #       instance_variables.collect{|v| instance_variable_get(v)._create_accessors('hash')}
    #     end
    #     return true
    #   end
  
    # NEW
    def _create_accessor(name)
      #puts "OBJECT._create_accessor '#{name}' for Object '#{self.class}'"
      meta = (class << self; self; end)
      meta.send(:attr_reader, name.to_sym)
    end
  
    # Attach hash as individual instance variables to self.
    # This is for manually attaching a hash of attributes to the current object.
    # Pass in translation procs to alter the keys or values.
    def _attach_as_instance_variables(hash, options={})
      #hash.each{|k,v| instance_variable_set("@#{k}", v)} if hash.is_a? Hash
      key_translator = options[:key_translator]
      value_translator = options[:value_translator]
      #puts ["ATTACH_AS_INSTANCE_VARIABLES", key_translator, value_translator].join(', ')
      if hash.is_a? Hash
        hash.each do |k,v|
          (k = key_translator.call(k)) if key_translator
          (v = value_translator.call(k, v)) if value_translator
          instance_variable_set("@#{k}", v)
        end
      end
    end
  
  end # Object
  
  
  refine Array do
    def _merge_object!(obj, name, delimiter, prefs, type, options={})
      #puts ["\n+++++ARRAY._merge_object", self.class, (obj.inspect), name, delimiter, prefs, type, options].join(', ')
      case
      # I added the 'values' option to capture values-only from hashes or arrays.
      # This is needed to generate array of database-names from rfm.
      when prefs=='values' && obj.is_a?(Hash); self.concat(obj.values)
      when prefs=='values' && obj.is_a?(Array); self.concat(obj)
      when prefs=='values'; self << obj
      when prefs=='shared' || type == 'attribute' && prefs.to_s != 'private' ; _merge_shared!(obj, name, delimiter, prefs, type, options)
      when prefs=='private'; _merge_instance!(obj, name, delimiter, prefs, type, options)
      else self << obj
      end
    end
  end # Array
  
  
  refine Hash do
  
    def _merge_object!(obj, name, delimiter, prefs, type, options={})
      #puts ["\n*****HASH._merge_object", "type: #{type}", "name: #{name}", "self.class: #{self.class}", "new_obj: #{(obj.to_s rescue obj.class)}", "delimiter: #{delimiter}", "prefs: #{prefs}", "options: #{options}"]
      output = case
               when prefs=='shared'
                 _merge_shared!(obj, name, delimiter, prefs, type, options)
               when prefs=='private'
                 _merge_instance!(obj, name, delimiter, prefs, type, options)
               when (self[name] || delimiter)
                 rslt = if delimiter
                          delimit_name =  obj._get_attribute(delimiter, options[:shared_variable_name]).to_s.downcase
                          #puts "MERGING delimited object with hash: self '#{self.class}' obj '#{obj.class}' name '#{name}' delim '#{delimiter}' delim_name '#{delimit_name}' options '#{options}'"
                          self[name] ||= options[:default_class].new
  
                          #self[name][delimit_name]=obj
                          # This is supposed to handle multiple elements who's delimiter value is the SAME.
                          self[name]._merge_delimited_object!(obj, delimit_name)
                        else
                          if name == options[:text_label]
                            self[name] << obj.to_s
                          else
                            self[name] = [self[name]].flatten
                            self[name] << obj
                          end
                        end
                 _create_accessor(name) if (options[:create_accessors].to_a & ['all','shared','hash']).any?
  
                 rslt
               else
                 rslt = self[name] = obj
                 _create_accessor(name) if (options[:create_accessors] & ['all','shared','hash']).any?
                 rslt
               end
      #puts ["\n*****HASH._merge_object! RESULT", self.to_yaml]
      #puts ["\n*****HASH._merge_object! RESULT PORTALS", (self.portals.to_yaml rescue 'no portals')]
      output
    end
  
    #   def _create_accessors options=[]
    #     #puts ['CREATE_ACCESSORS_for_HASH', self.class, options]
    #     options=[options].flatten.compact
    #     super and
    #     if (options & ['all', 'hash']).any?
    #       meta = (class << self; self; end)
    #       keys.each do |k|
    #         meta.send(:define_method, k) do
    #           self[k]
    #         end
    #       end
    #     end
    #   end
  
    def _create_accessor(name)
      #puts "HASH._create_accessor '#{name}' for Hash '#{self.class}'"
      meta = (class << self; self; end)
      meta.send(:define_method, name) do
        self[name]
      end
    end
  
  end # Hash

end # ObjectMergeRefinements