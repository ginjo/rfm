require 'delegate'

module Rfm
  # The Layout object represents a single FileMaker Pro layout. You use it to interact with 
  # records in FileMaker. *All* access to FileMaker data is done through a layout, and this
  # layout determines which _table_ you actually hit (since every layout is explicitly associated
  # with a particular table -- see FileMakers Layout->Layout Setup dialog box). You never specify
  # _table_ information directly in RFM.
  #
  # Also, the layout determines which _fields_ will be returned. If a layout contains only three
  # fields from a large table, only those three fields are returned. If a layout includes related
  # fields from another table, they are returned as well. And if the layout includes portals, all
  # data in the portals is returned (see Record::portal for details).
  #
  # As such, you can _significantly_ improve performance by limiting what you put on the layout.
  #
  # =Using Layouts
  #
  # The Layout object is where you get most of your work done. It includes methods for all
  # FileMaker actions:
  # 
  # * Layout::all
  # * Layout::any
  # * Layout::find
  # * Layout::edit
  # * Layout::create
  # * Layout::delete
  #
  # =Running Scripts
  # 
  # In FileMaker, execution of a script must accompany another action. For example, to run a script
  # called _Remove Duplicates_ with a found set that includes everybody
  # named _Bill_, do this:
  #
  #   myLayout.find({"First Name" => "Bill"}, :post_script => "Remove Duplicates")
  #
  # ==Controlling When the Script Runs
  #
  # When you perform an action in FileMaker, it always executes in this order:
  # 
  # 1. Perform any find
  # 2. Sort the records
  # 3. Return the results
  #
  # You can control when in the process the script runs. Each of these options is available:
  #
  # * *post_script* tells FileMaker to run the script after finding and sorting
  # * *pre_find_script* tells FileMaker to run the script _before_ finding
  # * *pre_sort_script* tells FileMaker to run the script _before_ sorting, but _after_ finding
  #
  # ==Passing Parameters to a Script
  # 
  # If you want to pass a parameter to the script, use the options above, but supply an array value
  # instead of a single string. For example:
  #
  #   myLayout.find({"First Name" => "Bill"}, :post_script => ["Remove Duplicates", 10])
  #
  # This sample runs the script called "Remove Duplicates" and passes it the value +10+ as its 
  # script parameter.
  #
  # =Common Options
  # 
  # Most of the methods on the Layout object accept an optional hash of +options+ to manipulate the
  # action. For example, when you perform a find, you will typiclaly get back _all_ matching records. 
  # If you want to limit the number of records returned, you can do this:
  #
  #   myLayout.find({"First Name" => "Bill"}, :max_records => 100)
  # 
  # The +:max_records+ option tells FileMaker to limit the number of records returned.
  #
  # This is the complete list of available options:
  # 
  # * *max_records* tells FileMaker how many records to return
  #
  # * *skip_records* tells FileMaker how many records in the found set to skip, before
  #   returning results; this is typically combined with +max_records+ to "page" through 
  #   records
  #
  # * *sort_field* tells FileMaker to sort the records by the specified field
  # 
  # * *sort_order* can be +descend+ or +ascend+ and determines the order
  #   of the sort when +sort_field+ is specified
  #
  # * *post_script* tells FileMaker to perform a script after carrying out the action; you 
  #   can pass the script name, or a two-element array, with the script name first, then the
  #   script parameter
  #
  # * *pre_find_script* is like +post_script+ except the script runs before any find is 
  #   performed
  #
  # * *pre_sort_script* is like +pre_find_script+ except the script runs after any find
  #   and before any sort
  # 
  # * *response_layout* tells FileMaker to switch layouts before producing the response; this
  #   is useful when you need a field on a layout to perform a find, edit, or create, but you
  #   want to improve performance by not including the field in the result
  #
  # * *logical_operator* can be +and+ or +or+ and tells FileMaker how to process multiple fields
  #   in a find request
  # 
  # * *modification_id* lets you pass in the modification id from a Record object with the request;
  #   when you do, the action will fail if the record was modified in FileMaker after it was retrieved
  #   by RFM but before the action was run
  #
  #
  # =Attributes
  #
  # The Layout object has a few useful attributes:
  #
  # * +name+ is the name of the layout
  #
  # * +field_controls+ is a hash of FieldControl objects, with the field names as keys. FieldControl's
  #   tell you about the field on the layout: how is it formatted and what value list is assigned
  #
  # Note: It is possible to put the same field on a layout more than once. When this is the case, the
  # value in +field_controls+ for that field is an array with one element representing each instance
  # of the field.
  # 
  # * +value_lists+ is a hash of arrays. The keys are value list names, and the values in the hash
  #   are arrays containing the actual value list items. +value_lists+ will include every value
  #   list that is attached to any field on the layout

  class Layout
    include Config

    meta_attr_accessor :db
    attr_reader :field_mapping
    attr_writer :resultset_meta
    def_delegator :db, :server
    #alias_method :database, :db  # This fails if db object hasn't been set yet with meta_attr_accessor

    def database
      db
    end

    attr_accessor :model #, :parent_layout, :subs
    def_delegators :meta, :field_controls, :value_lists
    def_delegators :resultset_meta, :date_format, :time_format, :timestamp_format, :field_meta, :portal_meta, :table

    # Methods that must be kept after rewrite!!!
    #     
    # field_mapping
    # db (database)
    # name
    # resultset_meta
    # date_format
    # time_format
    # timestamp_format
    # field_meta
    # field_controls
    # field_names
    # field_names_no_load
    # value_lists
    # count
    # total_count
    # portal_meta
    # portal_meta_no_load
    # portal_names
    # table
    # table_no_load
    # server

    # Initialize a layout object. You never really need to do this. Instead, just do this:
    # 
    #   myServer = Rfm::Server.new(...)
    #   myDatabase = myServer["Customers"]
    #   myLayout = myDatabase["Details"]
    #
    # This sample code gets a layout object representing the Details layout in the Customers database
    # on the FileMaker server.
    # 
    # In case it isn't obvious, this is more easily expressed this way:
    #
    #   myServer = Rfm::Server.new(...)
    #   myLayout = myServer["Customers"]["Details"]

    def initialize(*args) #name, db_obj
      # self.subs ||= []
      config(*args)
      raise Rfm::Error::RfmError.new(0, "New instance of Rfm::Layout has no name. Attempted name '#{state[:layout]}'.") if state[:layout].to_s == ''
      @loaded = false
      @meta = Metadata::LayoutMeta.new(self)
      self
    end

    def config(*args)
      super(:capture_strings_with=>[:layout])
      super(*args) do |params|
        (self.name = params[:strings][0]) if params && params[:strings] && params[:strings].any?
        (self.db = params[:objects][0]) if params && params[:objects] && params[:objects][0] && params[:objects][0].is_a?(Rfm::Database)
      end
    end

    alias_method :db_orig, :db
    def db
      db_orig || (self.db = Rfm::Database.new(state[:database], state[:account_name], state[:password], self))
    end

    # Returns a ResultSet object containing _every record_ in the table associated with this layout.
    def all(options = {})
      get_records('-findall', {}, options)
    end

    # Returns a ResultSet containing a single random record from the table associated with this layout.
    def any(options = {})
      get_records('-findany', {}, options)
    end

    # Finds a record. Typically you will pass in a hash of field names and values. For example:
    #
    #   myLayout.find({"First Name" => "Bill"})
    #
    # Values in the hash work just like value in FileMaker's Find mode. You can use any special
    # symbols (+==+, +...+, +>+, etc...).
    #
    # Create a Filemaker 'omit' request by including an :omit key with a value of true.
    # 
    #   myLayout.find :field1 => 'val1', :field2 => 'val2', :omit => true
    # 
    # Create multiple Filemaker find requests by passing an array of hashes to the #find method.
    # 
    #   myLayout.find [{:field1 => 'bill', :field2 => 'admin'}, {:field3 => 'inactive', :omit => true}, ...]
    # 
    # If the value of a field in a find request is an array of strings, the string values will be logically OR'd in the query.
    # 
    #   myLayout.find :fieldOne => ['bill','mike','bob'], :fieldTwo =>'staff'      
    #
    # If you pass anything other than a hash or an array as the first parameter, it is converted to a string and
    # assumed to be FileMaker's internal id for a record (the recid).
    #
    #   myLayout.find 54321
    #
    def find(find_criteria, options = {})
      #puts "layout.find-#{self.object_id}"
      options.merge!({:field_mapping => field_mapping.invert}) if field_mapping
      get_records(*Rfm::CompoundQuery.new(find_criteria, options))
    end

    # Access to raw -findquery command.
    def query(query_hash, options = {})
      get_records('-findquery', query_hash, options)
    end

    # Updates the contents of the record whose internal +recid+ is specified. Send in a hash of new
    # data in the +values+ parameter. Returns a RecordSet containing the modified record. For example:
    #
    #   recid = myLayout.find({"First Name" => "Bill"})[0].record_id
    #   myLayout.edit(recid, {"First Name" => "Steve"})
    #
    # The above code would find the first record with _Bill_ in the First Name field and change the 
    # first name to _Steve_.
    def edit(recid, values, options = {})
      get_records('-edit', {'-recid' => recid}.merge(values), options)
      #get_records('-edit', {'-recid' => recid}.merge(expand_repeats(values)), options) # attempt to set repeating fields.
    end

    # Creates a new record in the table associated with this layout. Pass field data as a hash in the 
    # +values+ parameter. Returns the newly created record in a RecordSet. You can use the returned
    # record to, ie, discover the values in auto-enter fields (like serial numbers). 
    #
    # For example:
    #
    #   result = myLayout.create({"First Name" => "Jerry", "Last Name" => "Robin"})
    #   id = result[0]["ID"]
    #
    # The above code adds a new record with first name _Jerry_ and last name _Robin_. It then
    # puts the value from the ID field (a serial number) into a ruby variable called +id+.
    def create(values, options = {})
      get_records('-new', values, options)
    end

    # Deletes the record with the specified internal recid. Returns a ResultSet with the deleted record.
    #
    # For example:
    #
    #   recid = myLayout.find({"First Name" => "Bill"})[0].record_id
    #   myLayout.delete(recid)
    # 
    # The above code finds every record with _Bill_ in the First Name field, then deletes the first one.
    def delete(recid, options = {})
      get_records('-delete', {'-recid' => recid}, options)
      return nil
    end

    # Retrieves metadata only, with an empty resultset.
    def view(options = {})
      get_records('-view', {}, options)
    end

    # Get the foundset_count only given criteria & options.
    def count(find_criteria, options={})
      find(find_criteria, options.merge({:max_records => 0})).foundset_count
    end

    def get_records(action, extra_params = {}, options = {})
      # TODO: See auto-grammar bypbass in connection.rb.
      grammar_option = state(options)[:grammar]
      options.merge!(:grammar=>grammar_option) if grammar_option
      template = options.delete :template

      # # TODO: Remove this code it is no longer used.
      # #include_portals = options[:include_portals] ? options.delete(:include_portals) : nil
      # include_portals = !options[:ignore_portals]

      # Apply mapping from :field_mapping, to send correct params in URL.
      prms = params.merge(extra_params)
      map = field_mapping.invert
      options.merge!({:field_mapping => map}) if map && !map.empty?
      # TODO: Make this part handle string AND symbol keys. (isn't this already done?)
      #map.each{|k,v| prms[k]=prms.delete(v) if prms[v]}

      #prms.dup.each_key{|k| prms[map[k.to_s]]=prms.delete(k) if map[k.to_s]}
      prms.dup.each_key do |k|
        new_key = map[k.to_s] || k
        if prms[new_key].is_a? Array
          prms[new_key].each_with_index do |v, i|
            prms["#{new_key}(#{i+1})"]=v
          end
          prms.delete new_key
        else
          prms[new_key]=prms.delete(k) if new_key != k
        end
        #puts "PRMS: #{new_key} #{prms[new_key].class} #{prms[new_key]}"
      end

      #c = Connection.new(action, prms, options, state.merge(:parent=>self))
      c = Connection.new(action, prms, options, self)
      #rslt = c.parse(template || :fmresultset, Rfm::Resultset.new(self, self))
      rslt = c.parse(template, Rfm::Resultset.new(self, self))
      capture_resultset_meta(rslt) unless resultset_meta_valid? #(@resultset_meta && @resultset_meta.error != '401')
      rslt
    end

    def params
      {"-db" => state[:database], "-lay" => self.name}
    end

    def name
      state[:layout].to_s
    end


    ###  Metadata from Layout  ###

    def meta
      @loaded ? @meta : load_layout
    end

    def field_names
      case
      when @loaded
        meta.field_names
      when @resultset_meta
        resultset_meta.field_names
      else meta.field_names
      end
    end

    def field_names
      # case
      # when @loaded; meta.field_names
      # when @resultset_meta; resultset_meta.field_names
      # else meta.field_names
      # end
      meta.field_names
    end

    def field_keys
      # case
      # when @loaded; @meta.field_keys
      # when @resultset_meta; @resultset_meta.field_keys
      # else meta.field_keys
      # end
      meta.field_keys
    end



    ###  Metadata from Resultset  ###

    def resultset_meta
      #@resultset_meta || view.meta
      resultset_meta_valid? ? @resultset_meta : view.meta
    end

    def resultset_meta_valid?
      if @resultset_meta && @resultset_meta.error != '401'
        true
      end
    end

    # Should always refresh
    def total_count
      view.total_count
    end

    def capture_resultset_meta(resultset)
      (@resultset_meta = resultset.clone.replace([])) #unless @resultset_meta
      @resultset_meta = resultset.meta
    end

    def portal_names
      return 'UNDER-CONTSTRUCTION'
    end




    ###  Utility  ###

    def load_layout
      #@loaded = true # This is first so parsing call to 'meta' wont cause infinite loop,
      # but I changed parsing template to refer directly to inst var instead of accessor method.
      connection = Connection.new('-view', {'-db' => state[:database], '-lay' => name}, {:grammar=>'FMPXMLLAYOUT'}, self)
      begin
        connection.parse(:fmpxmllayout, self)
        @loaded = true
      rescue
        @meta.clear
        raise $!
      end
      @meta
    end

    def check_for_errors(code=@meta['error'].to_i, raise_401=state[:raise_401])
      #puts ["\nRESULTSET#check_for_errors", code, raise_401]
      raise Rfm::Error.getError(code) if code != 0 && (code != 401 || raise_401)
    end

    def field_mapping
      @field_mapping ||= load_field_mapping(state[:field_mapping])
    end

    def load_field_mapping(mapping={})
      mapping = (mapping || {}).to_cih
      def mapping.invert
        super.to_cih
      end
      mapping
    end

    # Creates new class with layout name.
    def modelize
      @model ||= (
        model_name = name.to_s.gsub(/\W|_/, ' ').title_case.gsub(/\s/,'')
        #model_class = eval("::" + model_name + "= Class.new(Rfm::Base)")
        model_class = Rfm.const_defined?(model_name) ? Rfm.const_get(model_name) : Rfm.const_set(model_name, Class.new(Rfm::Base))
        model_class.class_exec(self) do |layout_obj|
          @layout = layout_obj
        end
        model_class.config :parent=>'@layout'
        model_class
      )
      #     rescue StandardError, SyntaxError
      #       puts "Error in layout#modelize: #{$!}"
      #       nil
    end

    def models
      #subs.collect{|s| s.model}
      [@model]
    end


    private :load_layout, :get_records, :params, :check_for_errors


  end # Layout
end # Rfm
