module Rfm
  # The Database object represents a single FileMaker Pro database. When you retrieve a Database
  # object from a server, its account name and password are set to the account name and password you 
  # used when initializing the Server object. You can override this of course:
  #
  #   my_database = my_server("Customers")
  #   my_database.account_name = "foo"
  #   my_database.password = "bar"
  #
  # =Accessing Layouts
  #
  # All interaction with FileMaker happens through a Layout object. You can get a Layout object
  # from the Database object like this:
  #
  #   my_layout = my_database.layout("Details")
  #
  # This code gets the Layout object representing the layout called Details in the database.
  #
  # Note: RFM does not talk to the server when you retrieve a Layout object in this way. Instead, it
  # simply assumes you know what you're talking about. If the layout you specify does not exist, you 
  # will get no error at this point. Instead, you'll get an error when you use the Layout object methods
  # to talk to FileMaker. This makes debugging a little less convenient, but it would introduce too much
  # overhead to hit the server at this point.
  #
  # The Database object has a +layout+ attribute that provides alternate access to Layout objects. It acts
  # like a hash of Layout objects, one for each accessible layout in the database. So, for example, you
  # can do this if you want to print out a list of all layouts:
  # 
  #   my_database.layouts.each {|layout| puts layout.name }
  # 
  # The Database::layout attribute is actually a LayoutFactory object, although it subclasses hash, so it
  # should work in all the ways you expect. Note, though, that it is completely empty until the first time
  # you attempt to access its elements. At that (lazy) point, it hits FileMaker, loads in the list of layouts,
  # and constructs a Layout object for each one. In other words, it incurrs no overhead until you use it.
  #
  # =Accessing Scripts
  #
  # If for some reason you need to enumerate the scripts in a database, you can do so:
  #  
  #   my_database.scripts.each { |script| puts script.name }
  # 
  # The Database::script attribute is actually a ScriptFactory object, although it subclasses hash, so it
  # should work in all the ways you expect. Note, though, that it is completely empty until the first time
  # you attempt to access its elements. At that (lazy) point, it hits FileMaker, loads in the list of scripts,
  # and constructs a Script object for each one. In other words, it incurrs no overhead until you use it. 
  #
  # Note: You don't need a Script object to _run_ a script (see the Layout object instead).
  #
  # =Attributes
  # 
  # In addition to the +layout+ attribute, Server has a few other useful attributes:
  #
  # * *server* is the Server object this database comes from
  # * *name* is the name of this database
  # * *options* is a hash of all server options used to initialize this server
  class Database
    attr_accessor :server, :name, :account_name, :password, :fm_layout, :script
    
    # Initialize a database object. You never really need to do this. Instead, just do this:
    # 
    #   my_server = Rfm::Server.new(...)
    #   my_database = my_server.db("Customers")
    #
    # This sample code gets a database object representing the Customers database on the FileMaker server.
    def initialize(name, server)
      self.name = name
      self.server = server
      self.account_name = server.options[:account_name] || ""
      self.password = server.options[:password] || ""
      self.fm_layout = Factories::LayoutFactory.new(server, self)
      self.script = Factories::ScriptFactory.new(server, self)
    end

    # Access the Layout object representing a layout in this database. For example:
    #
    #   myDatabase.layout('Details')
    #
    # would return a Layout object representing the _Details_
    # layout in the database.
    #
    # Note: RFM never talks to the server until you perform an action. The Layout object
    # returned is created on the fly and assumed to refer to a valid layout, but you will
    # get no error at this point if the layout you specify doesn't exist. Instead, you'll
    # receive an error when you actually try to perform some action it.
    def layout(name)
      self.fm_layout[name]
    end
    
    #TODO remove in next major release.
    def [](layout_name) # :nodoc:
      warn "#[] is deprecated, use #layout instead"
      layout(layout_name)
    end
    
    # List all layouts belonging to a given database
    def layouts
      @fm_layout.all
    end
    
    # List all scripts belonging to a given database
    def scripts
      @script.all
    end

  end
end