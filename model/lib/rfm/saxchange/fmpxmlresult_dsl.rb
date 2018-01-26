module Rfm

  # This is for enhanced Binding methods in attachment procs.
  # It's not necessary, unless you want to do 'binding[:some_local_var_or_method]'.
  using Refinements
      
  SaxChange::Template.register('fmpxmlresult') do
  
    initial_object "Rfm::Resultset.new(**config)"
    attach_elements '_meta'
    attach_attributes '_meta'
    create_accessors 'all'
    
    # TODO: Fill these in to filter ox xmldecl attribute callback calls.
    #       The goal is to wrap the loose attributes from ox parsings in an array.
    attribute 'version' do
      attach ['_xmldecl']
    end
    
    attribute 'encoding' do
      attach ['_xmldecl']
    end
    
    attribute 'standalone' do
      attach ['_xmldecl']
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
      attach ['cursor', 'Rfm::Metadata::Field', ':allocate']
      delimiter 'name'
      attach_attributes 'private'
      before_close ['object', 'field_definition_element_close_callback', 'self']
    end
  
    element 'resultset' do
      attach 'none'
      attribute 'found' do
        as_name 'count'
      end
    end
    
    element 'row' do
      #attach 'none'
      attach do |env_binding|
        puts "Element attachment proc, cursor '#{@tag}', initial_attributes '#{@initial_attributes}'"
        instance_exec(env_binding, &handler.config[:record_proc]) if handler.config[:record_proc].is_a?(Proc)
      end
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
        attach do |env_binding|
          puts "Attribute attachment proc, cursor '#{@tag}', attr-label '#{env_binding[:label]}', attr-value '#{env_binding[:v]}', object: #{@object.class}"
        end
        compact true
      end
    end
    
  end # document
end # Rfm