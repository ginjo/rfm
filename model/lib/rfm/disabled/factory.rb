# The classes in this module are used internally by RFM and are not intended for outside
# use.
#
# Author::    Geoff Coffey  (mailto:gwcoffey@gmail.com)
# Copyright:: Copyright (c) 2007 Six Fried Rice, LLC and Mufaddal Khumri
# License::   See MIT-LICENSE for details


module Rfm

  module Factory
    # Acquired from Rfm::Base
    @models ||= []

    extend Config
    config :parent=>'Rfm::Config'

    class ServerFactory < Rfm::CaseInsensitiveHash
      def [](*args)
        options = Factory.get_config(*args)
        host = options[:strings].delete_at(0) || options[:host]
        super(host) || (self[host] = Rfm::Server.new(*args))   #(host, options.rfm_filter(:account_name, :password, :delete=>true)))
        # This part reconfigures the named server, if you pass it new config in the [] method.
        # This breaks some specs in all [] methods in Factory. Consider undoing this. See readme-dev.
        #   super(host).config(options) if (options)
        #   super(host)
      end
    end # ServerFactory


    class DbFactory < Rfm::CaseInsensitiveHash # :nodoc: all
      #       extend Config
      #       config :parent=>'@server'

      def initialize(server)
        extend Config
        config :parent=>'@server'
        @server = server
        @loaded = false
      end

      def [](*args)
        # was: (dbname, acnt=nil, pass=nil)
        options = get_config(*args)
        name = options[:strings].delete_at(0) || options[:database]
        #account_name = options[:strings].delete_at(0) || options[:account_name]
        #password = options[:strings].delete_at(0) || options[:password]
        super(name) || (self[name] = Rfm::Database.new(@server, *args))  #(name, account_name, password, @server))
        # This part reconfigures the named database, if you pass it new config in the [] method.
        #   super(name).config({:account_name=>account_name, :password=>password}.merge(options)) if (account_name or password or options)
        #   super(name)
      end

      def all
        if !@loaded
          c = Connection.new('-dbnames', {}, {:grammar=>'FMPXMLRESULT'}, @server)
          c.parse('fmpxml_minimal.yml', {})['data'].each{|k,v| (self[k] = Rfm::Database.new(v['text'], @server)) if k.to_s != '' && v['text']}
          #r = c.parse('fmpxml_minimal.yml', {})
          @loaded = true
        end
        self
      end

      def names
        self.values.collect{|v| v.name}
      end

    end # DbFactory



    class LayoutFactory < Rfm::CaseInsensitiveHash # :nodoc: all

      #       extend Config
      #       config :parent=>'@database'

      def initialize(server, database)
        extend Config
        config :parent=>'@database'
        @server = server
        @database = database
        @loaded = false
      end

      def [](*args) # was layout_name
        options = get_config(*args)
        name = options[:strings].delete_at(0) || options[:layout]
        super(name) || (self[name] = Rfm::Layout.new(@database, *args))   #(name, @database, options))
        # This part reconfigures the named layout, if you pass it new config in the [] method.
        #   super(name).config({:layout=>name}.merge(options)) if options
        #   super(name)
      end

      def all
        if !@loaded
          c = Connection.new('-layoutnames', {"-db" => @database.name}, {:grammar=>'FMPXMLRESULT'}, @database)
          c.parse('fmpxml_minimal.yml', {})['data'].each{|k,v| (self[k] = Rfm::Layout.new(v['text'], @database)) if k.to_s != '' && v['text']}
          @loaded = true
        end
        self
      end

      def names
        values.collect{|v| v.name}
      end

      # Acquired from Rfm::Base
      def modelize(filter = /.*/)
        all.values.each{|lay| lay.modelize if lay.name.match(filter)}
        models
      end

      # Acquired from Rfm::Base
      def models
        rslt = {}
        each do |k,lay|
          layout_models = lay.models
          rslt[k] = layout_models if (!layout_models.nil? && !layout_models.empty?)
        end
        rslt
      end

    end # LayoutFactory



    class ScriptFactory < Rfm::CaseInsensitiveHash # :nodoc: all

      #       extend Config
      #       config :parent=>'@database'

      def initialize(server, database)
        extend Config
        config :parent=>'@database'
        @server = server
        @database = database
        @loaded = false
      end

      def [](script_name)
        super or (self[script_name] = Rfm::Metadata::Script.new(script_name, @database))
      end

      def all
        if !@loaded
          c = Connection.new('-scriptnames', {"-db" => @database.name}, {:grammar=>'FMPXMLRESULT'}, @database)
          c.parse('fmpxml_minimal.yml', {})['data'].each{|k,v| (self[k] = Rfm::Metadata::Script.new(v['text'], @database)) if k.to_s != '' && v['text']}
          @loaded = true
        end
        self
      end

      def names
        values.collect{|v| v.name}
      end

    end # ScriptFactory



    class << self

      # Acquired from Rfm::Base
      attr_accessor :models
      # Shortcut to Factory.db().layouts.modelize()
      # If first parameter is regex, it is used for modelize filter.
      # Otherwise, parameters are passed to Factory.database
      def modelize(*args)
        regx = args[0].is_a?(Regexp) ? args.shift : /.*/
        db(*args).layouts.modelize(regx)
      end

      def servers
        @servers ||= ServerFactory.new
      end    

      # Returns Rfm::Server instance, given config hash or array
      def server(*conf)
        Server.new(*conf)
      end

      # Returns Rfm::Db instance, given config hash or array
      def db(*conf)
        Database.new(*conf)
      end

      alias_method :database, :db

      # Returns Rfm::Layout instance, given config hash or array
      def layout(*conf)
        Layout.new(*conf)
      end

    end # class << self

  end # Factory
end # Rfm
