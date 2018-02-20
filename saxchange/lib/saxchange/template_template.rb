# This saxchange template will parse xml-based saxchange templates.
SaxChange::Template.register(:template_template) do
  global do
    compact true
    element 'element' do
      attach Array
      as_name 'elements'
      #initial_object Array
    end
  end
end