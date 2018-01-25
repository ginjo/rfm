module Rfm
      
  SaxChange::Template.register('fmpxmlresult') do
    initial_object "Rfm::Resultset.new(**config)"
    attach_elements '_meta'
    attach_attributes '_meta'
    create_accessors 'all'
    
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
      attach 'none'
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
        attach 'values'
        compact true
      end
    end
    
  end # document
end # Rfm