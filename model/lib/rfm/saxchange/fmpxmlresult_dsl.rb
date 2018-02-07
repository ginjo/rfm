module Rfm

  # This is for enhanced Binding methods in attachment procs.
  # It's not necessary, unless you want to do 'binding[:some_local_var_or_method]'.
  using Refinements
  
  # This is for running the object attachment command directly from the template.
  # I don't think we want to do that, but for experimental purposes...
  #using ObjectMergeRefinements
      
  SaxChange::Template.register('fmpxmlresult') do
  
    initial_object { Rfm::Resultset.new(**config) }
    attach_elements '_meta'
    attach_attributes '_meta'
    create_accessors 'all'
    
    # TODO: Fill these in to filter ox xmldecl attribute callback calls.
    #       The goal is to wrap the loose attributes from ox parsings in an array.
    attribute 'version' do
      attach '_xmldecl'
    end
    
    attribute 'encoding' do
      attach '_xmldecl'
    end
    
    attribute 'standalone' do
      attach '_xmldecl'
    end
    
    element 'fmpxmlresult' do
      attach 'none'
    end
    
    element 'product'
    
    element 'errorcode' do
      attach 'none'
      attribute 'text' do
        as_name 'error'
      end
    end
    
    element 'database'
    
    element 'metadata' do
      attach 'none'
    end
    
    element 'field' do
      #attach ['cursor', 'Rfm::Metadata::Field', ':allocate']
      initial_object { Rfm::Metadata::Field.allocate }
      attach 'none'
      delimiter 'name'
      attach_attributes 'private'
      before_close { @object.field_definition_element_close_callback(self) }
    end
  
    element 'resultset' do
      attach 'none'
      attribute 'found' do
        as_name 'count'
      end
    end
    
    element 'row' do
      attach 'none'
      # attach do |env_binding|
      #   puts "Element attachment proc, cursor '#{@tag}', initial_attributes '#{@initial_attributes}'"
      #   instance_exec(env_binding, &handler.config[:record_proc]) if handler.config[:record_proc].is_a?(Proc)
      # end
      attribute 'modid' do
        attach 'none'
      end
      attribute 'recordid' do
        attach 'none'
      end
    end
    
    element 'col' do
      attach 'none'
    end
    
    element 'data' do
      attach 'none'
      
      attribute 'text' do
        #attach 'values'
        
        # If a record_proc exists, run it, otherwise return the
        # correct attachment prefs for this attribute 'values'.
        # If the record_proc returns anything, it will be sent back
        # to the cursor as an attachment pref, causing cursor to attach
        # this attribute anyway. So return nil from record_proc, if you
        # don't want the result object to fill with records.
        # 'env' is binding of cursor method where this is yielded.
        
        attach do |env|
          record_proc = handler.config[:record_proc]
          if record_proc.is_a?(Proc)
            instance_exec(env[:v], top.object, env, &record_proc)
          else
            'values'
          end
        end
        
        compact true
      end # attribute
    end # element
    
  end # document
end # Rfm