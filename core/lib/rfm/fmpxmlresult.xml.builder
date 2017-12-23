#!/usr/bin/env ruby

# Return @records as fmpxmlresult.xml
# Note that all element and attribute names in fmpxmlresult grammar MUST BE ALLCAPS.
@keys = @records[0].attribute_names
xml.FMPXMLRESULT :XMLNS=>"http://www.filemaker.com/fmpxmlresult" do
  xml.ERRORCODE '0'
  xml.PRODUCT :BUILD=>'1.0', :NAME=>'esalen', :VERSION=>'2'
  xml.DATABASE :DATEFORMAT=>"M/d/yyyy", :LAYOUT=>'', :NAME=>'order_items', :RECORDS=>@records.size, :TIMEFORMAT=>"h:mm:ss a", :TIMESTAMPFORMAT=>"M/d/yyyy h:mm:ss a"
  xml.METADATA do
    @keys.each do |name|
      type = case @records[0][name].class.to_s
        when /decimal|fixnum|int|float/i; "NUMBER"
        when /^time$/i; "TIMESTAMP"  # All sql timestamp fields seem to be coming thru as "Time".
        when /^date$/i; "DATE"
        when /timestamp|datetime/i; "TIMESTAMP"
        else "TEXT"
      end
      xml.FIELD :NAME=>name, :EMPTYOK=>'yes', :MAXREPEAT=>"1", :TYPE=>type
    end
  end
  xml.RESULTSET(:FOUND=>@records.size.to_i) do
    @records.each do |r|
      xml.ROW :MODID=>"0", :RECORDID=>r.id do
        @keys.each do |k|
          xml.COL do
            xml.DATA r[k]
          end
        end
      end
    end
  end
end
