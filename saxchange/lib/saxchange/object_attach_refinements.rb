module ObjectAttachRefinements
  
  # Generic methods to aid in attachment of ruby objects to other ruby objects.
  # This is intended to facilitate the sax parser in attaching parsed objects
  # to other parsed objects. This module replaces ObjectMergeRefinements.

  refine Object do
    # Provide array or hash of tuples (2-element-array-or-hash):
    #  [[:a, 1], [:b, 2], {c:3}, {d:4}]
    #  {a:2, b:2, c:3}
    # Options-hash is optional, but must be sent as 2nd arg 'attach_tuples([tuples], {options})'.
    # Duplicate keys are ok... collisions will be handled.
    #
    def attach_tuples(tuples, **opts)
      #puts "\nATTACH_TUPLES '#{tuples.to_a[0]}', opts '#{opts}'"
      return if [:none, 'none', :hidden, 'hidden'].include?(opts[:style])
      tuples.each do |t|
        case
        when t.is_a?(Hash)
          attach_tuples(t.to_a, opts)
        when t.is_a?(Array) && t.size==2
          #puts "#{t}"
          attach_tuple(t[0], t[1], opts)
        when t.is_a?(Array)
          attach_tuples(t, opts)
        else
          SaxChange.logger.debug "Object#attach_tuples: The value '#{t}' is not a tuple"
          self << t if self.is_a?(Array)
        end
      end
    end
    
    # Attach tuple to this object.
    # If style == shared (or empty), attach to shared ivar,
    # otherwise attach to private ivar.
    def attach_tuple(k,v, **opts)
      k = k.downcase
      v = v.compact_values if opts[:compact] == true
      v = [v].flatten(1) if opts[:style].to_s[/array/i]
      #puts "\nObject:#{self.class}#attach_tuple k,v,opts '#{k}, #{v}, #{opts}'"
      dat = keyed_data(k)
      if [:shared, 'shared', ''].include?(opts[:style].to_s)
        shared_var_name = opts[:shared_variable_name] || 'attributes'
        eval("@#{shared_var_name} ||= opts[:default_class].new || {}").attach_tuple(k,v, **opts.merge(style: 'hash'))
      else
        instance_variable_set(:"@#{k}", dat ? dat.collide(v, opts) : v)
        create_accessor(k) if opts[:create_accessors] && opts[:create_accessors]&.any?
      end
    end
    
    # Handle collision between this object and other,
    # deciding whether to put both objects in a hash,
    # or in an array.
    def collide(other, opts)
      #puts "\nObject:#{self.class}#collide self,other,opts '#{self}, #{other}, #{opts}'"
      delim = opts[:delimiter]
      case
        # Not sure if this (style-array) should be here.
        # It might be more of an attach_tuple operation,
        # rather than a collision operation.
        when opts[:style].to_s == 'array'
          #puts "Object:#{self.class}#collide is array"
          [self, other].flatten(1)
        when delim && any_key?(delim) && other.any_key?(delim)
          #puts "Object:#{self.class}#collide both are keyed objects"
          #{keyed_data(delim) => self, other.keyed_data(delim) => other}
          (opts[:default_class].new || {}).merge(keyed_data(delim).to_s.downcase => self, other.keyed_data(delim).to_s.downcase => other)
        when delim && is_a?(Hash) && other.any_key?(delim)
          #puts "Object:#{self.class}#collide self is hash, other is keyed"
          merge(other.keyed_data(delim).to_s.downcase => other)
        else
          #puts "Object:#{self.class}#collide else basic array"
          [self, other].flatten(1)
      end
    end # collide
    
    # Check for existance of specific ivar.
    def any_key?(key)
      #puts "Object#any_key? arg '#{key.to_s}'"
      instance_variables.include?(:"@#{key}")
    end
    
    # Get data from specific ivar.
    def keyed_data(key)
      instance_variable_get(:"@#{key}")
    end
    
    # Create accessor method for ivar.
    def create_accessor(name)
      name = name.downcase
      # meta = (class << self; self; end)
      # meta.send(:attr_reader, name.to_sym)
      singleton_class.send(:attr_reader, name)
    end
    
    def compact_values
      self
    end
    
  end # Object
  
  refine Hash do
  
    # Attach tuple to this object as hash key=>value.
    def attach_tuple(k,v, **opts)
      k = k.downcase
      v = v.compact_values if opts[:compact] == true
      v = [v].flatten(1) if opts[:style].to_s[/array/i]
      #puts "\nHash:#{self.class}#attach_tuple with k,v,opts '#{k}, #{v}, #{opts}'"
      # Block given to 'merge' determines how to handle collisions,
      # with |key, old-dat, new-dat| .
      if [:private, :shared, 'private', 'shared'].include?(opts[:style])
        super
      else
        merge!(k => v) do |x,y,z|  
          self[x] = y.collide(z, opts)
        end
        create_accessor(k) if opts[:create_accessors] && opts[:create_accessors]&.any?
      end
    end
    
    # Check for existance of specific hash element,
    # or super (object ivar)
    def any_key?(key)
      has_key?(key) || super
    end
    
    # Get data from specific hash element,
    # or super (object ivar)
    def keyed_data(key)
      self[key] || super
    end
    
    # Create accessor method for specific hash element.
    def create_accessor(name)
      name = name.downcase
      #puts "HASH._create_accessor '#{name}' for Hash '#{self.class}'"
      #meta = (class << self; self; end)
      singleton_class.send(:define_method, name) do
        self[name]
      end
    end
    
    def compact_values
      size == 1 ? values[0] : self
    end        
  end # Hash
  
  refine Array do
    # Attach tuple to this array.
    def attach_tuple(k,v, **opts)
      v = v.compact_values if opts[:compact] == true
      #puts "\nArray:#{self.class}#attach_tuple k,v,opts '#{k}, #{v}, #{opts}'"
      if [:private, :shared, 'private', 'shared'].include?(opts[:style])
        super
      else
        self << v
      end
    end
    
    def compact_values
      size == 1 ? first : self
    end
  end # Array

end # ObjectAttachRefinements

