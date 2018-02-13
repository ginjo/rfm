module ObjectAttachRefinements


  refine Object do
    
    # Provide array or hash of tuples (2-element-array-or-hash):
    #  [[:a, 1], [:b, 2], {c:3}, {d:4}]
    #  {a:2, b:2, c:3}
    # Options-hash is optional, but must be sent as 2nd arg 'attach_tuples([tuples], {options})'.
    # Duplicate keys are ok... collisions will be handled.
    #
    def attach_tuples(tuples, **opts)
      # TODO: style-none should be filtered out in cursor, so it never calls attach_tuples.
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
          SaxChange.logger.debug "Object#attach_tuples: The value #{t} is not a tuple"
          self << t if self.is_a?(Array)
        end
      end
    end
    
    def attach_tuple(k,v, **opts)
      #puts "Object:#{self.class}#attach_tuple k,v,opts '#{k}, #{v}, #{opts}'"
      dat = keyed_data(k)
      if [:shared, 'shared', ''].include?(opts[:style].to_s)
        shared_var_name = opts[:shared_variable_name] || 'attributes'
        eval("@#{shared_var_name} ||= {}").attach_tuple(k,v, delimiter: opts[:delimiter])
      else
        instance_variable_set(:"@#{k}", dat ? dat.collide(v, opts) : v)
      end
    end
    
    def collide(other, opts)
      #puts "Object:#{self.class}#collide self,other,delim,opts '#{self}, #{other}, #{opts[:delimiter]}, #{opts}'"
      delim = opts[:delimiter]
      case
        # Not sure if this (style-array) should be here.
        # It might be more of an attach_tuple operation,
        # rather than a collision operation.
        when opts[:style].to_s == 'array'
          [self, other].flatten(1)
        when delim && has_key?(delim) && other.has_key?(delim)
          {keyed_data(delim) => self, other.keyed_data(delim) => other}
        when delim && is_a?(Hash) && other.has_key?(delim)
          merge(other.keyed_data(delim) => other)
        else
          [self, other].flatten(1)
      end
    end # collide
    
    def has_key?(key)
      instance_variables.include?(:"@#{key.to_s}")
    end
    
    def keyed_data(key)
      instance_variable_get(:"@#{key.to_s}")
    end
    
  end # Object
  
  refine Hash do
    def attach_tuple(k,v, **opts)
      #puts "Hash:#{self.class}#attach_tuple with k,v,opts '#{k}, #{v}, #{opts}'"
      # Block given to 'merge' determines how to handle collisions,
      # with |key, old-dat, new-dat| .
      if [:private, :shared, 'private', 'shared'].include?(opts[:style])
        super
      else
        merge!(k=>v) do |x,y,z|  
          self[x] = y.collide(z, opts)
        end
      end
    end
    
    def keyed_data(key)
      self[key] || super
    end
  end # Hash
  
  refine Array do
    def attach_tuple(k,v, **opts)
      #puts "Array:#{self.class}#attach_tuple k,v,opts '#{k}, #{v}, #{opts}'"
      if [:private, :shared, 'private', 'shared'].include?(opts[:style])
        super
      else
        self << v
      end
    end
  end # Array

end # ObjectAttachRefinements