module Rfm
  # The Record object represents a single FileMaker record. You typically get them from ResultSet objects.
  # For example, you might use a Layout object to find some records:
  #
  #   results = myLayout.find({"First Name" => "Bill"})
  #
  # The +results+ variable in this example now contains a ResultSet object. ResultSets are really just arrays of
  # Record objects (with a little extra added in). So you can get a record object just like you would access any 
  # typical array element:
  #
  #   first_record = results[0]
  #
  # You can find out how many record were returned:
  #
  #   record_count = results.size
  #
  # And you can of course iterate:
  # 
  #   results.each (|record|
  #     // you can work with the record here
  #   )
  #
  # =Accessing Field Data
  #
  # You can access field data in the Record object in two ways. Typically, you simply treat Record like a hash
  # (because it _is_ a hash...I love OOP). Keys are field names:
  # 
  #   first = myRecord["First Name"]
  #   last = myRecord["Last Name"]
  #
  # If your field naming conventions mean that your field names are also valid Ruby symbol named (ie: they contain only
  # letters, numbers, and underscores) then you can treat them like attributes of the record. For example, if your fields
  # are called "first_name" and "last_name" you can do this:
  #
  #   first = myRecord.first_name
  #   last = myRecord.last_name
  #
  # Note: This shortcut will fail (in a rather mysterious way) if your field name happens to match any real attribute
  # name of a Record object. For instance, you may have a field called "server". If you try this:
  # 
  #   server_name = myRecord.server
  # 
  # you'll actually set +server_name+ to the Rfm::Server object this Record came from. This won't fail until you try
  # to treat it as a String somewhere else in your code. It is also possible a future version of Rfm will include
  # new attributes on the Record class which may clash with your field names. This will cause perfectly valid code
  # today to fail later when you upgrade. If you can't stomach this kind of insanity, stick with the hash-like
  # method of field access, which has none of these limitations. Also note that the +myRecord[]+ method is probably
  # somewhat faster since it doesn't go through +method_missing+.
  #
  # =Accessing Repeating Fields
  #
  # If you have a repeating field, RFM simply returns an array:
  #
  #   val1 = myRecord["Price"][0]
  #   val2 = myRecord["Price"][1]
  #
  # In the above example, the Price field is a repeating field. The code puts the first repetition in a variable called 
  # +val1+ and the second in a variable called +val2+.
  #
  # It is not currently possible to create or edit a record's repeating fields beyond the first repitition, using Rfm.
  #
  # =Accessing Portals
  #
  # If the ResultSet includes portals (because the layout it comes from has portals on it) you can access them
  # using the Record::portals attribute. It is a hash with table occurrence names for keys, and arrays of Record
  # objects for values. In other words, you can do this:
  #
  #   myRecord.portals["Orders"].each {|record|
  #     puts record["Order Number"]
  #   }
  #
  # This code iterates through the rows of the _Orders_ portal.
  #
  #  As a convenience, you can call a specific portal as a method on your record, if the table occurrence name does
  # not have any characters that are prohibited in ruby method names, just as you can call a field with a method:
  #   
  #   myRecord.orders.each {|portal_row|
  #     puts portal_row["Order Number"]
  #   }
  #   
  # =Field Types and Ruby Types
  #
  # RFM automatically converts data from FileMaker into a Ruby object with the most reasonable type possible. The 
  # type are mapped thusly:
  #
  # * *Text* fields are converted to Ruby String objects
  # 
  # * *Number* fields are converted to Ruby BigDecimal objects (the basic Ruby numeric types have
  #   much less precision and range than FileMaker number fields)
  #
  # * *Date* fields are converted to Ruby Date objects
  #
  # * *Time* fields are converted to Ruby DateTime objects (you can ignore the date component)
  #
  # * *Timestamp* fields are converted to Ruby DateTime objects
  #
  # * *Container* fields are converted to Ruby URI objects
  #
  # =Attributes
  #
  # In addition to +portals+, the Record object has these useful attributes:
  #
  # * *record_id* is FileMaker's internal identifier for this record (_not_ any ID field you might have
  #   in your table); you need a +record_id+ to edit or delete a record
  #
  # * *mod_id* is the modification identifier for the record; whenever a record is modified, its +mod_id+
  #   changes so you can tell if the Record object you're looking at is up-to-date as compared to another
  #   copy of the same record
  class Record < Rfm::CaseInsensitiveHash

    attr_accessor :layout #, :resultset
    attr_reader :record_id, :mod_id, :portals
    def_delegators :layout, :db, :database, :server, :field_meta, :portal_meta, :field_names, :portal_names

    # This is called during the parsing process, but only to allow creation of the correct type of model instance.
    # This is also called by the end-user when constructing a new empty record, but it is called from the model subclass.
    def self.new(*args) # resultset
      record = case
        # Get model from layout, then allocate record.
        # This should only use model class if the class already exists,
        # since we don't want to create classes that aren't defined by the user - they won't be persistant.
      when args[0].is_a?(Resultset) && args[0].layout && args[0].layout.model
        args[0].layout.modelize.allocate
        # Allocate instance of Rfm::Record.
      else
        self.allocate
      end

      record.send(:initialize, *args)
      record
      # rescue
      #   puts "Record.new bombed and is defaulting to super.new. Error: #{$!}"
      #   super
    end

    def initialize(*args) # resultset, attributes
      @mods            ||= {}
      @portals        ||= Rfm::CaseInsensitiveHash.new
      options = args.rfm_extract_options!
      if args[0].is_a?(Resultset)
        @layout = args[0].layout
      elsif self.is_a?(Base)
        @layout = self.class.layout
        @layout.field_keys.each do |field|
          self[field] = nil
        end
        self.update_attributes(options) unless options == {}
        self.merge!(@mods) unless @mods == {}
        @loaded = true
      end
      _attach_as_instance_variables(args[1]) if args[1].is_a? Hash
      #@loaded = true
      self
    end

    # Saves local changes to the Record object back to Filemaker. For example:
    #
    #   myLayout.find({"First Name" => "Bill"}).each(|record|
    #     record["First Name"] = "Steve"
    #     record.save
    #   )
    #
    # This code finds every record with _Bill_ in the First Name field, then changes the first name to 
    # Steve.
    #
    # Note: This method is smart enough to not bother saving if nothing has changed. So there's no need
    # to optimize on your end. Just save, and if you've changed the record it will be saved. If not, no
    # server hit is incurred.
    def save
      # self.merge!(layout.edit(self.record_id, @mods)[0]) if @mods.size > 0
      self.replace_with_fresh_data(layout.edit(self.record_id, @mods)[0]) if @mods.size > 0
      @mods.clear
    end

    # Like Record::save, except it fails (and raises an error) if the underlying record in FileMaker was
    # modified after the record was fetched but before it was saved. In other words, prevents you from
    # accidentally overwriting changes someone else made to the record.
    def save_if_not_modified
      # self.merge!(layout.edit(@record_id, @mods, {:modification_id => @mod_id})[0]) if @mods.size > 0
      self.replace_with_fresh_data(layout.edit(@record_id, @mods, {:modification_id => @mod_id})[0]) if @mods.size > 0
      @mods.clear
    end

    # Gets the value of a field from the record. For example:
    #
    #   first = myRecord["First Name"]
    #   last = myRecord["Last Name"]
    #
    # This sample puts the first and last name from the record into Ruby variables.
    #
    # You can also update a field:
    #
    #   myRecord["First Name"] = "Sophia"
    #
    # When you do, the change is noted, but *the data is not updated in FileMaker*. You must call
    # Record::save or Record::save_if_not_modified to actually save the data.
    def [](key)
      # Added by wbr, 2013-03-31
      return super unless @loaded
      return fetch(key.to_s.downcase)
    rescue IndexError
      raise Rfm::ParameterError, "#{key} does not exists as a field in the current Filemaker layout." unless key.to_s == '' #unless (!layout or self.key?(key_string))
    end

    def respond_to?(symbol, include_private = false)
      return true if self.include?(symbol.to_s)
      super
    end

    def []=(key, val)
      key_string = key.to_s.downcase
      key_string_base = key_string.split('.')[0]
      return super unless @loaded # is this needed? yes, for loading fresh records.
      unless self.key?(key_string) || (layout.field_keys.include?(key_string_base) rescue nil)
        raise Rfm::ParameterError, "You attempted to modify a field (#{key_string}) that does not exist in the current Filemaker layout."
      end
      # @mods[key_string] = val
      # TODO: This needs cleaning up.
      # TODO: can we get field_type from record instead?
      @mods[key_string] = if [Date, Time, DateTime].member?(val.class)
        field_type = layout.field_meta[key_string.to_sym].result
        case field_type
        when 'time'
          val.strftime(layout.time_format)
        when 'date'
          val.strftime(layout.date_format)
        when 'timestamp'
          val.strftime(layout.timestamp_format)
        else
          val
        end
      else
        val
      end
      super(key, val)
    end

    def field_names
      layout.field_names
    end

    def replace_with_fresh_data(record)
      self.replace record
      [:@mod_id, :@record_id, :@portals, :@mods].each do |var|
        self.instance_variable_set var, record.instance_variable_get(var) || {}
      end
      self
    end


    private

    def method_missing (symbol, *attrs, &block)
      method = symbol.to_s
      return self[method] if self.key?(method)
      return @portals[method] if @portals and @portals.key?(method)

      if method =~ /(=)$/
        return self[$`] = attrs.first if self.key?($`)
      end
      super
    end

  end # Record
end # Rfm
