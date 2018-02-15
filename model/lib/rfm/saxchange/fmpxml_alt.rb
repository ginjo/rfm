SaxChange::Template.register_yaml(<<-EEOOFF)

# Another (better?) minimal FMPXMLRESULT parser.
---
name: fmpxml_alt
elements:
- name: fmpxmlresult
  elements:
  - name: metadata
    elements:
    - name: field
      as_name: fields
  - name: resultset
    elements:
    - name: row
      as_name: rows
      compact: true
      elements:
      - name: col
        as_name: columns
        compact: true
        
EEOOFF