# This module includes classes that represent FileMaker data. When you communicate with FileMaker
# using, ie, the Layout object, you typically get back ResultSet objects. These contain Records,
# which in turn contain Fields, Portals, and arrays of data.
#
# Author::    Geoff Coffey  (mailto:gwcoffey@gmail.com)
# Copyright:: Copyright (c) 2007 Six Fried Rice, LLC and Mufaddal Khumri
# License::   See MIT-LICENSE for details

require 'bigdecimal'
require 'rfm/record'

module Rfm

  # The ResultSet object represents a set of records in FileMaker. It is, in every way, a real Ruby
  # Array, so everything you expect to be able to do with an Array can be done with a ResultSet as well.
  # In this case, the elements in the array are Record objects.
  #
  # Here's a typical example, displaying the results of a Find:
  #
  #   myServer = Rfm::Server.new(...)
  #   results = myServer["Customers"]["Details"].find("First Name" => "Bill")
  #   results.each {|record|
  #     puts record["First Name"]
  #     puts record["Last Name"]
  #     puts record["Email Address"]
  #   }
  #
  # =Attributes
  #
  # The ResultSet object has these attributes:
  #
  # * *field_meta* is a hash with field names for keys and Field objects for values; it provides 
  #   info about the fields in the ResultSet
  #
  # * *portal_meta* is a hash with table occurrence names for keys and arrays of Field objects for values;
  #   it provides metadata about the portals in the ResultSet and the Fields on those portals

  class Resultset < Array
    include Config

    attr_reader :layout, :meta, :calling_object
    #     attr_reader :layout, :database, :server, :calling_object, :doc
    #     attr_reader :field_meta, :portal_meta, :include_portals, :datasource
    #     attr_reader :date_format, :time_format, :timestamp_format
    #     attr_reader :total_count, :foundset_count, :table
    #def_delegators :layout, :db, :database
    # alias_method :db, :database
    def_delegators :meta, :field_meta, :portal_meta, :date_format, :time_format, :timestamp_format, :total_count, :foundset_count, :fetch_size, :table, :error, :field_names, :field_keys, :portal_names

    class << self
      def load_data(data, object=self.new)
        Rfm::SaxParser.parse(data, :fmresultset, object)
      end
    end

    # Initializes a new ResultSet object. You will probably never do this your self (instead, use the Layout
    # object to get various ResultSet obejects).
    #
    # If you feel so inclined, though, pass a Server object, and some +fmpxmlresult+ compliant XML in a String.
    #
    # =Attributes
    #
    # The ResultSet object includes several useful attributes:
    #
    # * *fields* is a hash (with field names for keys and Field objects for values). It includes an entry for
    #   every field in the ResultSet. Note: You don't use Field objects to access _data_. If you're after 
    #   data, get a Record object (ResultSet is an array of records). Field objects tell you about the fields
    #   (their type, repetitions, and so forth) in case you find that information useful programmatically.
    #
    #   Note: keys in the +fields+ hash are downcased for convenience (and [] automatically downcases on 
    #   lookup, so it should be seamless). But if you +each+ a field hash and need to know a field's real
    #   name, with correct case, do +myField.name+ instead of relying on the key in the hash.
    #
    # * *portals* is a hash (with table occurrence names for keys and Field objects for values). If your
    #   layout contains portals, you can find out what fields they contain here. Again, if it's the data you're
    #   after, you want to look at the Record object.
    def initialize(*args) # parent, layout
      config(*args)
      self.meta
    end # initialize

    def config(*args)
      super do |params|
        (@layout = params[:objects][0]) if params &&
          params[:objects] &&
          params[:objects][0] &&
          params[:objects][0].is_a?(Rfm::Layout)
      end
    end

    # This method was added for situations where a layout was not provided at resultset instantiation,
    # such as when loading a resultset from an xml file.
    def layout
      @layout ||= (Layout.new(meta.layout, self) if meta.respond_to? :layout)
    end

    def database
      layout.database
    end

    alias_method :db, :database

    def server
      database.server
    end

    def meta
      # Access the meta inst var here.
      @meta ||= Metadata::ResultsetMeta.new
    end

    # Deprecated on 7/29/2014. Stop using.
    def handle_new_record(attributes)
      r = Rfm::Record.new(self, attributes, {})
      self << r
      r
    end

    def end_datasource_element_callback(cursor)
      %w(date_format time_format timestamp_format).each{|f| convert_date_time_format(send(f))}
      @meta.attach_layout_object_from_cursor(cursor)
    end

    private

    def check_for_errors(error_code=@meta['error'].to_i, raise_401=state[:raise_401])
      #puts ["\nRESULTSET#check_for_errors", "meta[:error] #{@meta[:error]}", "error_code: #{error_code}", "raise_401: #{raise_401}"]
      raise Rfm::Error.getError(error_code) if error_code != 0 && (error_code != 401 || raise_401)
    end

    def convert_date_time_format(fm_format)
      fm_format.gsub!('MM', '%m')
      fm_format.gsub!('dd', '%d')
      fm_format.gsub!('yyyy', '%Y')
      fm_format.gsub!('HH', '%H')
      fm_format.gsub!('mm', '%M')
      fm_format.gsub!('ss', '%S')
      fm_format
    end

  end
end
