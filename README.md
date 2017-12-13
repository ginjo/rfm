<!--
  See YARD documentation - https://github.com/lsegal/yard/wiki/GettingStarted
  
  Yard is not the same as markdown - Yard is for ruby and can use any markup language,
  whereas Markdown is just another markup language.
  
  Rubydoc.info uses yard and can use markdown and other markup languages.
  To update ginjo-rfm's yard documentation from github's master branch,
  first find 'rfm' on rubydoc.info, then in list-view click the update button
  on the right of the screen.
  To preview this file in yard, run 'rake yard'
  
  Github uses markdown or rdoc (maybe others?).
  To preview this file in plain markdown, edit in TextMate and
  choose Bundles/Markdown/Preview menu option.
-->

# ginjo-rfm

Rfm is a Ruby-Filemaker adapter, a gem that provides an interface between Filemaker Server and Ruby. Query your Filemaker database, browse result records as persistent objects, and create/update/delete records with a syntax similar to ActiveRecord. Ginjo-rfm picks up from the lardawge-rfm gem and continues to refine code and fix bugs. Version 3 removes the dependency on ActiveSupport and is now a completely independent Gem, able to run most of its core features without requiring any other supporting Gems. ActiveModel features can be activated by adding activemodel to your Gemfile (or requiring activemodel manually).

Ginjo-rfm version 3 has been tested successfully on Ruby 1.8.7 thru 2.1.3.


## Documentation & Links

* Gem                 <https://rubygems.org/gems/ginjo-rfm>
* Rdoc                <http://rubydoc.info/github/ginjo/rfm>
* Github              <https://github.com/ginjo/rfm>
* Discussion          <http://groups.google.com/group/rfmcommunity>
* Original            <http://sixfriedrice.com/wp/products/rfm/>
* Lardawge            <https://github.com/lardawge/rfm>

## Requirements

Ginjo-rfm should run on any machine with a standard ruby installation. Ginjo-rfm's primary function is to interact with Filemaker Server,
however ginjo-rfm does not have to be installed on your Filemaker server - it can be installed on any machine that has network/internet access
to your Filemaker server.

Ginjo-rfm will work with any Filemaker server that supports the fmresultset.xml grammar over the http protocol.
Since Filemaker Pro client does not support this, Filemaker server is required. Follow Filemaker Server's instructions
for setting up "Custom Web Publishing".

Ginjo-rfm works great with Rails, but it does not require Rails.
You can write simple and powerful stand-alone ruby scripts that use ginjo-rfm to talk to a Filemaker server.

## Download & Installation

Find the latest stable release at Rubygems.org.

In your Gemfile.

    gem 'ginjo-rfm', :require=>'rfm'

Or manually.

    gem install 'ginjo-rfm'

You can find the latest development release on github.

    gem 'ginjo-rfm', :git=>'https://github.com/ginjo/rfm.git', :branch=>'master'

Ginjo-rfm v3 can be run without any other gems, allowing you to create models to interact with your Filemaker servers, layouts, tables, records, and data. If you want the additional features provided by ActiveModel, just add activemodel to your Gemfile (or require it manually). Ginjo-rfm v3 will use the built-in Ruby XML parser REXML by default. If you want to use one of the other supported parsers (libxml-ruby, nokogiri, ox), just add it to your Gemfile or require it manually. If you have several Ruby XML parsers installed, you can specify which one you want Rfm to use by setting the configuration option :parser with one of the supported options (:libxml, :nokogiri, :ox, :rexml).

Note that while this gem is officially named "ginjo-rfm", you require/load it into your Ruby scripts as simply "rfm". This is in keeping with the original rfm gem from Sixfriedrice and with other forks of the rfm gem.



## Ginjo-rfm Basic Usage

The first step in getting connected to your Filemaker databases with Rfm (assuming your Filemaker Server is properly set up - see the Filemaker Server instructions for "Custom Web Publishing") is to store your configuration settings in a yaml file or in the RFM_CONFIG hash. The second step is creating a Ruby class (often referred to as a "model" in this documentation) that represent a layout in your Filemaker database. Create as many models as you wish, each pointing to a layout/table-occurrence that you want to work with. The third step is using your new models to query, create, update, and delete records in your Filemaker database. Here's an example setup for a simple order-item table.

config/rfm.yml

    :host: my.host.com
    :account_name: myname
    :password: somepass
    :database: MyFmDb
  
app/models/order\_item.rb

    class OrderItem < Rfm::Base
      config :layout => 'order_item_layout'
    end
      
app/controllers/order\_item\_controller.rb

    def show
      @record = OrderItem.find params[:id]
    end


### Configuration

In previous versions of Rfm, you may have stored your configuration settings in a variable or constant, then passed those settings to Rfm::Server.new(MY_SETTINGS). Now you can put your configuration settings in a rfm.yml file at the root of your project or in your project's config/ directory, and Rfm will use those settings automatically when building your Model's Server, Database, and Layout objects.

rfm.yml

    :ssl: true
    :timeout: 10
    :port: 443
    :host: my.host.com
    :account_name: myname
    :password: somepass
    :database: MyFmDb

Or put your configuration settings in a hash called RFM_CONFIG. Rfm will pick those up just as with the yaml file.

    RFM_CONFIG = {
      :host          => 'my.host.com',
      :database      => 'MyFmDb',
      :account_name  => 'myname',
      :password      => 'somepass',
      :ssl           => true,
      :port          => 443,
      :timeout       => 10
    }

You can use configuration subgroups to separate global settings from environment-specific settings.

    :ssl: true
    :root_cert: false
    :timeout: 10
    :port: 443
    :development:
      :host: dev.mydomain.com
      :account_name: admin
      :password: pass
      :database: DevFmDb
    :production:
      :host: live.mydomain.com
      :account_name: admin
      :password: pass
      :database: LiveFmDb

Then in your environment files (or wherever you put environment-specific configuration in your Ruby project),
specifiy which subgroup to use.

     RFM_CONFIG = {:use => :development}

You can use configuration subgroups to contain any arbitrary groups of settings.

    :ssl: true
    :root_cert: false
    :timeout: 10
    :port: 443
    :customer1:
      :host: customer1.com
      :account_name: cust1
      :password: pass
      :database: custOneFmDb
    :customer2:
      :host: customer2.com
      :account_name: cust2
      :password: pass
      :database: custTwoFmDb

Use the configuration setting method `config` to set configuration for specific objects, like Rfm models. When you pass a `:use => :subgroup` to the `config` method, you're saying use that subgroup of settings (on top of any existing upstream configuration).

    class MyModel < Rfm::Base
      config :use => :customer1, :layout => 'some_layout'
    end
  
The current hierarchy of configurable objects in Rfm, starting at the top, is:

* rfm.yml      # file of settings in yaml format
* RFM_CONFIG   # user-defined hash
* Rfm::Config  # top-level config module, inherits settings from RFM_CONFIG and rfm.yml
* Rfm::Factory # where server, database, and layout objects are managed, inherits settings from Rfm::Config
* Rfm::Base    # master modeling class, inherits settings from Rfm::Config
* MyModel      # sublcassed custom modeling class, inherits settings from Rfm::Base

You can also include or extend the Rfm::Config module in any object in your project to gain Rfm configuration abilities for that object.

    module MyModule
      include Rfm::Config
      config :host => 'myhost.com', :database => 'mydb', :account_name => 'name', :password => 'pass'
      # inherits settings from Rfm::Config by default
    end

    class Person < Rfm::Base
      config :parent => MyModule, :layout => 'some_layout'
      # using :parent to set where this object inherits config settings from
    end

Use `get_config` to view the compiled configuration settings for any object. Configuration compilation will start at the top (rfm.yml), then work down the hierarchy of objects to wherever you call the `get_config` method, merging in all global settings along the way. Subgroupings of settings will also be merged, if they are specified in a subgroup filter. A subgroup filter occurs any time you put `:use => :subgroup` in your configuration setting. You can have multiple subgroup filters, and when configuration compilation occurs, all subgroup filters are stacked up into an array and processed in order (as if you typed `:use=>[:subgroup1, :subgroup2, subgroup3, ...]` which is also allowed). `get_config` returns a compiled configuration hash, leaving all configuration settings in all modules and classes un-touched.

    Person.get_config
    
    # =>  {:ssl => true, :timeout => 10, :root_cert => false, :port => 443,
          :host => 'myhost', :database => 'mydb', :layout => 'some_layout',
          :account_name => 'name', :password => 'pass'
          }
  
#### Configuration Options

Following are all of the recognized configuration options, including defaults if applicable.
See `Rfm::Config::CONFIG_KEYS` for a list of currently allowed configuration options.

    :host             => 'localhost'
    :port             
    :ssl              => true
    :root_cert        => true
    :root_cert_name   => ''
    :root_cert_path   => '/'
    :account_name     => ''
    :password         => ''
    :proxy            => false              # Pass an array of Net::HTTP::Proxy options (p_addr, p_port = nil, p_user = nil, p_pass = nil).
    :log_actions      => false
    :log_responses    => false
    :log_parser       => false
    :warn_on_redirect => true
    :raise_on_401     => false
    :timeout          => 60
    
    :use                                    # Use configuration subgroups, or filter configuration subgoups.
    :layout                                 # Specify the name of the layout to use.
    :parent           => 'Rfm::Config'      # The parent configuration object of the current configuration object, as string.
    :file_name        => 'rfm.yml           # Name of configuration file to load yaml from.
    :file_path        => ['', 'config/']    # Array of additional file paths to look for configuration file.
    :parser                                 # Prefferred XML parser. Can be :libxml, :nokogiri, :ox, :rexml.
                                            # You must also require the parsing gem or specify it in your gemfile,
                                            # if not using the built-in Ruby XML parser REXML. 
                                            # You only need to use this option if you have multiple
                                            # parsing gems loaded and want to use a specfic one. 
                                            # Otherwise, Rfm will use the best parser it can find amongst your currently loaded parsing gems.
    :ignore_bad_data   => nil                # Instruct Rfm to ignore data mismatch errors when loading a resultset.
    :decimal_separator => '.'               # FileMaker uses local number format of the server. It stores input as text.
                                            # So on european servers a number value of '1.200,50' is considered valid and interpreted as 1200.5
                                            # To support this, :decimal_separator can be configured and any other characters than digits and the separator are ignored

### Using Models

Rfm models provide easy access, modeling, and persistence of your Filemaker data. A ginjo-rfm model is basically an alias to a specific layout in your Filemaker database and provides all of the query options found in a classic rfm layout object. The model and/or the layout object is where you do most of your work with rfm. For more details about what methods and options are available to a model or layout object, see the documentation for the {Rfm::Layout} and {Rfm::Base} classes.

    class User < Rfm::Base
      config :layout => 'my_user_layout'
      attr_accessor :password
    end
    
    @user = User.new(:login => 'bill', :password => 'xxxxxxxx', :email => 'my@email.com')
    @user.encrypt_password
    @user.save!
    
    @user.record_id
    # => '12345'
    
    @user.field_names
    # => ['login', 'encryptedPassword', 'email', 'groups', 'lastLogin' ]
    
    User.total_count
    # => 35467
    
    @user = User.find 12345
    @user.update_attributes(:login => 'william', :email => 'myother@email.com')
    @user.save!
  
If using Rails, put your model code in files within your models/ directory.

app/models/user.rb

    class User < Rfm::Base
      config :layout => 'user_layout'
    end

If you prefer, you can create models on-the-fly from any layout.

    my_rfm_layout_object.modelize
    
    # => MyLayoutName   (subclassed from Rfm::Base, represented by your layout's name)

Or create models for an entire database, all at once.

    Rfm.modelize /_xml/i, 'my_database', :my_config_group
    
    # => [MyLayoutXml, AnotherLayoutXml, ThirdLayoutXml, AndSoOnXml, ...]
    # The regex in the first parameter is optional and filters the layout names in the specified database.
    # Omit the regex parameter to modelize all possible layouts in the specified database (careful with this one!).

With ActiveModel loaded, you get callbacks, validations, errors, serialization, and a handful of other features extracted from Rails ActiveRecord. Not all ActiveModel features are supported (yet) in ginjo-rfm, but adapters can be hand-rolled in the meantime.

In your Gemfile

    gem 'activemodel'

Or without Bundler

    require 'active_model'

Then use ActiveModel features in your Rfm models

    class MyModel < Rfm::Base
      before_create    :encrypt_password
      after_validate   "puts 'yay!'"
      validates        :email, :presence => true
    end

    @my_model = MyModel.new
    @my_model.valid?
    @my_model.save!
    @my_model.errors

To learn more about ActiveModel, see the ActiveModel or RubyOnRails documentation:

* <http://rubydoc.info/gems/activemodel/frames>
* <http://api.rubyonrails.org/>
* <http://guides.rubyonrails.org/active_record_validations_callbacks.html>

Once you have an Rfm model or layout, you can use any of the standard Rfm commands to create, search, edit, and delete records. To learn more about these commands, see below for Databases, Layouts, Resultsets, and Records. Or checkout the API documentation for Rfm::Server, Rfm::Database, Rfm::Layout, Rfm::Record, and Rfm::Base.

#### Two Small Changes in Rfm Return Values

(From Rfm v2 onward) When using Models to retrieve records using the `any` method or the `find(record_id)` method, the return values will be single Rfm::Record objects. This differs from the original Rfm behavior of these methods when accessed directly from the the Rfm::Layout instance, where the return value is always a Rfm::Resultset.

    MyModel.find(record_id)  ==  my_layout.find(record_id)[0]
    MyModel.any              ==  my_layout.any[0]


### Getting Rfm Server, Database, and Layout Objects Manually

Well... not entirely manually. To get server, db, and layout objects as in previous versions of Rfm, see the section "Working with classic Rfm features". Newer versions of ginjo-rfm can use the configuration options to build these objects.

Create a layout object using default configuration settings.

    my_layout = Rfm.layout 'layout_name'
  
Create a layout object using a subgroup of configuration settings.

    my_layout = Rfm.layout :subgroup_name
  
Create a layout object passing in a layout name, multiple config subgroups to merge, and specific settings.

    my_layout = Rfm.layout 'layout_name', :other_server, :log_actions => true
  
The same can be done for servers and databases.

    my_server   = Rfm.server 'my.host.com'
    my_database = Rfm.database :development, :ssl => false, :root_cert => false 
    my_database = Rfm.db :production
    # db and database are interchangeable aliases in Ginjo-rfm 2.0
  
You can query your Filemaker objects for the familiar meta-data.

    my_server.databases.all.names
    my_server.databases['MyFmDb']
    my_database.layouts
    my_layout.value_lists
    my_layout.field_names
    my_layout.portal_meta

Here are two new fun Layout methods:

    my_layout.total_count # => total records in table
    my_layout.count(:some_field => 'search criteria', ...)   # Returns foundset_count only, no records.

See the API documentation for the lowdown on new methods in Rfm Server, Database, and Layout objects.

### Shortcuts, Tips & Tricks

All Rfm methods that take a configuration hash have two possible shortcuts.

(1) If you pass a symbol before the hash, it is interpreted as subgroup specification or subgroup filter

    config :mygroup, :layout => 'mylayout'
    # This will add the following configuration options to the object you called 'config' on.
    # :use => :mygroup, :layout => 'mylayout'
  
    get_config :othergroup
    # This will return global configuration options merged with configuration options from :othergroup.
    # :use => [:mygroup, :othergroup], :layout => 'mylayout'

(2) If you pass a string before any symbols or hashes, it is interpreted as one of several possible configuration settings - usually a layout name, a database name, or a server hostname. The interpretation is dependent on the method being called. Not all methods will make use of a string parameter.

    class MyModel < Rfm::Base
      config 'MyLayoutName'
      # In this context, this is the same as
      # config :layout => 'MyLayoutName'
    end
  
    Rfm.database 'MyDatabaseName'
    # In this context, this is the same as
    # Rfm.database :database => 'MyDatabaseName'
  
    Rfm.modelize 'MyDatabaseName', :group1
    # In this context, this is the same as
    # Rfm.modelize :database => 'MyDatabaseName', :use => :group1

Just about anything you can do with a Rfm layout, you can also do with a Rfm model.

    MyModel.total_count
    MyModel.field_names
    MyModel.database.name
  
There are a number of methods within Rfm that have been made accessible from the top-level Rfm module. Note that the server/database/layout methods are new to Rfm and are not the same as Rfm::Server, Rfm::Database, and Rfm::Layout. See the above section on "Getting Rfm Server, Database, and Layout Objects Manually" for an overview of how to use the new server/database/layout methods.

    # Any of these methods can be accessed via Rfm.<method_name>
    
    Rfm::Factory    :servers, :server, :db, :database, :layout, :models, :modelize
    Rfm::Config     :config, :get_config, :config_clear
    Rfm::Resultset  :ignore_bad_data
    Rfm::SaxParser  :backend
  
If you are working with a Filemaker database that returns codes like '?' for a missing value in a date field, Rfm will throw an error. Set your main configuration, your server, or your layout to `ignore_bad_data true`, if you want Rfm to silently ignore data mismatch errors when loading resultset data. If ActiveRecord is loaded, and your resultset is loaded into a Rfm model, your model records will log these errors in the @errors attribute.

    Rfm.config :ignore_bad_data => true
    
    class MyModel < Rfm::Base
      config 'my_layout'
    end
    
    result = MyModel.find(:name => 'mike')
    # Assuming the Filemaker field 'some_date_field' contains a bad date value '?'
    result[0].errors.full_messages
    # ['some_date_field invalid date']
    
    # To be more specific about what objects you want to ignore data errors
    MyModel.layout.ignore_bad_data true

## Working with "Classic" Rfm Features

All of Rfm's original features and functions are available as they were before, though some low-level functionality has changed slightly. See the documentation for each module & class for the specifics on low-level methods and functionality.


### Connecting

IMPORTANT:SSL and Certificate verification are on by default. Please see Server#new in rdocs for explanation and setup.
You connect with the Rfm::Server object. This little buddy will be your window into FileMaker data.

    require 'rfm'

    my_server = Rfm::Server.new(
      :host           => 'myservername',
      :account_name   => 'user',
      :password       => 'pw',
      :ssl            => false
    )

if your web publishing engine runs on a port other than 80, you can provide the port number as well:

    my_server = Rfm::Server.new(
      :host           => 'myservername',
      :account_name   => 'user',
      :password       => 'pw',
      :port           => 8080, 
      :ssl            => false,
      :root_cert      => false
    )

### Databases and Layouts

All access to data in FileMaker's XML interface is done through layouts, and layouts live in databases. The Rfm::Server object has a collection of databases called 'db'. So to get ahold of a database called "My Database", you can do this:

    my_db = my_server.db["My Database"]

As a convenience, you can do this too:

    my_db = my_server["My Database"]

Finally, if you want to introspect the server and find out what databases are available, you can do this:

    all_dbs = my_server.db.all

In any case, you get back Rfm::Database objects. A database object in turn has a property called "layout":

    my_layout = my_db.layout["My Layout"]

Again, for convenience:

    my_layout = my_db["My Layout"]

And to get them all:

    all_layouts = my_db.layout.all

Bringing it all together, you can do this to go straight from a server to a specific layout:

    my_layout = my_server["My Database"]["My Layout"]

### Working with Layouts

Once you have a layout object, you can start doing some real work. To get every record from the layout:

    my_layout.all   # be careful with this

To get a random record:

    my_layout.any

To find every record with "Arizona" in the "State" field:

    my_layout.find({"State" => "Arizona"})

To add a new record with my personal info:

    my_layout.create({
      :first_name   => "Geoff",
      :last_name    => "Coffey",
      :email        => "gwcoffey@gmail.com"}
    )

Notice that in this case I used symbols instead of strings for the hash keys. The API will accept either form, so if your field names don't have whitespace or punctuation, you might prefer the symbol notation.

To edit the record whose recid (filemaker internal record id) is 200:

    my_layout.edit(200, {:first_name => 'Mamie'})

Note: See the "Record Objects" section below for more on editing records.

To delete the record whose recid is 200:

    my_layout.delete(200)

All of these methods return an Rfm::Resultset object (see below), and every one of them takes an optional parameter (the very last one) with additional options. For example, to find just a page full of records, you can do this:

    my_layout.find({:state => "AZ"}, {:max_records => 10, :skip_records => 100})

For a complete list of the available options, see the "Common Options" section in the layout.rb file.

Finally, if filemaker returns an error when executing any of these methods, an error will be raised in your Ruby script. There is one exception to this, though. If a find results in no records being found (FileMaker error # 401) I just ignore it and return you a Resultset with zero records in it. If you prefer an error in this case, add :raise_on_401 => true to the options you pass the Rfm::Server when you create it.


### Resultset and Record Objects

Any method on the Layout object that returns data will return a Resultset object. Rfm::Resultset is a subclass of Array, so first and foremost, you can use it like any other array:

    my_result = my_layout.any
    my_result.size  # returns '1'
    my_result[0]    # returns the first record (an Rfm::Record object)

The Resultset object also tells you information about the fields and portals in the result. Resultset#field\_meta and Resultset#portal\_meta are both standard Ruby hashes, with strings for keys. The fields hash has Rfm::Metadata::Field objects for values. The portals hash has another hash for its values. This nested hash is the fields on the portal. This would print out all the field names:

    my_result.field_meta.each { |name, field| puts name }
  
Or, as a convenience, you can do this:

    my_result.field_names

This would print out the tables each portal on the layout is associated with. Below each table name, and indented, it will print the names of all the fields on each portal.

    my_result.portals.each { |table, fields|
      puts "table: #{table}"
      fields.each { |name, field| puts "\t#{name}"}
    }

Also as a convenience, you can do this:

    my_result.portal_names

But most importantly, the Resultset contains record objects. Rfm::Record is a subclass of Hash, so it can be used in many standard ways. This code would print the value in the 'first_name' field in the first record of the Resultset:

    my_record = my_result[0]
    puts my_record["first_name"]

As a convenience, if your field names are valid Ruby method names (ie, they don't have spaces or odd punctuation in them), you can do this instead:

    puts my_record.first_name

Since Resultsets are arrays and Records are hashes, you can take advantage of Ruby's wonderful expressiveness. For example, to get a comma-separated list of the full names of all the people in California, you could do this:

    my_layout.find(:state => 'CA').collect {|rec| "#{rec.first_name} #{rec.last_name}"}.join(", ")

Record objects can also be edited:

    my_record.first_name = 'Isabel'

Once you have made a series of edits, you can save them back to the database like this:

    my_record.save

The save operation causes the record to be reloaded from the database, so any changes that have been made outside your script will also be picked up after the save.

If you want to detect concurrent modification, you can do this instead:

    my_record.save_if_not_modified

This version will refuse to update the database and raise an error if the record was modified after it was loaded but before it was saved.

Record objects also have portals. While the portals in a Resultset tell you about the tables and fields the portals show, the portals in a Record have the actual data. For example, if an Order record has Line Item records, you could do this:

    my_order = order_layout.any[0]  # the [0] is important!
    my_lines = my_order.portals["Line Items"]

At the end of the previous block of code, my_lines is an array of Record objects. In this case, they are the records in the "Line Items" portal for the particular order record. You can then operate on them as you would any other record. 

NOTE: Fields on a portal have the table name and the "::" stripped off of their names if they belong to the table the portal is tied to. In other words, if our "Line Items" portal includes a quantity field and a price field, you would do this:

    my_lines[0]["Quantity"]
    my_lines[0]["Price"]

You would NOT do this:

    my_lines[0]["Line Items::Quantity"]
    my_lines[0]["Line Items::Quantity"]

My feeling is that the table name is redundant and cumbersome if it is the same as the portal's table. This is also up for debate.

Again, you can string things together with Ruby. This will calculate the total dollar amount of the order:

    total = 0.0
    my_order.portals["Line Items"].each {|line| total += line.quantity * line.price}

### Data Types

FileMaker's field types are coerced to Ruby types thusly:

    Text Field       -> String object  
    Number Field     -> BigDecimal object  # see below  
    Date Field       -> Date object  
    Time Field       -> DateTime object # see below  
    TimeStamp Field  -> DateTime object  
    Container Field  -> URI object  

FileMaker's number field is insanely robust. The only data type in Ruby that can handle the same magnitude and precision of a FileMaker number is Ruby's BigDecimal. (This is an extension class, so you have to require 'bigdecimal' to use it yourself). Unfortuantely, BigDecimal is not a "normal" Ruby numeric class, so it might be really annoying that your tiny filemaker numbers have to go this route. This is a great topic for debate.

Also, Ruby doesn't have a Time type that stores just a normal time (with no date attached). The Time class in Ruby is a lot like DateTime, or a Timestamp in FileMaker. When I get a Time field from FileMaker, I turn it into a DateTime object, and set its date to the oldest date Ruby supports. You can still compare these in all the normal ways, so this should be fine, but it will look weird if you, ie, to_s one and see an odd date attached to your time.

Finally, container fields will come back as URI objects. You can:

  - use Net::HTTP to download the contents of the container field using this URI
  - to_s the URI and use it as the src attribute of an HTML image tag
  - etc...

Specifically, the URI refers to the _contents_ of the container field. When accessed, the file, picture, or movie in the field will be downloaded.

### Troubleshooting

There are two cheesy methods to help track down problems. When you create a server object, you can provide two additional optional parameters:

:log_actions
When this is 'true' your script will write every URL it sends to the web publishing engine to standard out. For the rails users, this means the action url will wind up in your WEBrick or Mongrel log. If you can't make sense of what you're getting, you might try copying the URL into your browser to see what is actually coming back from FileMaker.

:log_responses
When this is 'true' your script will dump the actual response it got from FileMaker to standard out (again, in rails, check your logs).

So, for an annoying, but detailed load of output, make a connection like this:

    my_server => Rfm::Server.new(
      :host             => 'myservername',
      :account_name     => 'user',
      :password         => 'pw',
      :log_actions      => true,
      :log_responses    => true
    )

### Source Code

If you were tracking ginjo-rfm on github before the switch to version 2.0.0, please accept my humblest apologies for making a mess of the branching. The pre 2.0.0 edge branch has become master, and the pre 2.0.0 master branch has become ginjo-1-4-stable. I don't intend to make that kind of hard reset again, at least not on public branches. Master will be the branch to find the latest-greatest public source, and 'stable' branches will emerge as necessary to preserve historical releases.

### Still To Do

Repeating field compatibility, more coverage of Filemaker's query syntax, more error classes, more specs, and more documentation.




## Version Highlights

### Version  3.0

There are many changes in version 3, but most of them are under the hood. Here are some highlights.

* Compatibility with Ruby 2.1.2 (and 2.0.0, 1.9.3, 1.8.7).

* XML parsing rewrite.
The entire XML parsing engine of Rfm has been rewritten to use only the sax/stream parsing schemes of the supported Ruby XML parsers (libxml-ruby, nokogiri, ox, rexml). There were two main goals in this rewrite: 1, to separate the xml parsing code from the Rfm/Filemaker objects, and 2, to remove the hard dependency on ActiveSupport. See below for parsing configuration options.

* Better logging capabilities.
Added Rfm.logger, Rfm.logger=, Config.logger, Config#logger, and config(:logger=>(...)).

* Added field-mapping awareness to :sort_field query option.

* Relaxed requirement that query option keys be symbols - can now be strings or symbols.

* Detached resultset from record, so record doesn't drag resultset around with it.

* Bug fixes and refinements in modeling, configuration, metadata access, and Rfm object instantiation.

See the changelog or the commit history for more details on changes in ginjo-rfm v3.

### Version 2.1

* Portals are now included by default.
  Removed `:include_portals` query option in favor of `:ignore_portals`.
  Added `:max_portal_rows` query option.
* Added field-remapping framework to allow model fields with different names than Filemaker fields.

        class User < Rfm::Base
          config :field_mapping => {
            #<filemaker-field-name>  =>  <rfm-field-name>
            'userName'               => 'login',
            'First Name'             => 'first_name',
            'Last Name'              => 'last_name',
            'IDperson'               => 'person_id'     
          }
        end

        User.find(:login=>'bill')    # => [{'login' => 'bill', 'first_name' => 'Bill', ...}, ...]

* Fixed date/time/timestamp translations when writing data to Filemaker.
* Detached new Server objects from Factory.servers hash, so wont reuse or stack-up servers.
* Added grammar translation layer between xml parser and Rfm, allowing all supported xml grammars to be used with Rfm.
  This will also streamline changes/additions to Filemaker's xml grammar(s).
* Added ability to manually import fmpresultset and fmpxmlresult data (from file, variable, etc.).

        Rfm::Resultset.load_data(file_or_string).

* Compatibility fixes for Ruby 1.9.
* Configuration `:use` option now works for all Rfm objects that respond to `config`.


### Version 2.0

* Rails-like modeling with ActiveModel
* Support for multiple XML Parsers
* Configuration API
* Compound Filemaker queries with omitable requests
* Full metadata support


#### Data Modeling with ActiveModel
  
If you can load ActiveModel in your project, you can have model callbacks, validations, and other ActiveModel features.
If you can't load ActiveModel (because you're using something incompatible, like Rails 2),
you can still use Rfm models... minus the ActiveModel-specific features like callbacks and validations. Rfm models give you basic
data modeling with easy configuration and CRUD features.

    class User < Rfm::Base
      config      :layout=>'user_layout'
      before_save :encrypt_password
      validate    :valid_email_address
    end
  
    @user = User.new :username => 'bill', :password => 'pass'
    @user.email = 'my@email.com'
    @user.save!


#### Choice of XML Parsers

Note that this section only applies to ginjo-rfm v2. See notes for ginjo-rfm v3 for v3 parsing options. 

Ginjo-rfm 2.0 uses ActiveSupport's XmlMini parsing interface, which has built-in support for
LibXML, Nokogiri, and REXML. Additionally, ginjo-rfm includes adapters for Ox and Hpricot parsing.
You can specifiy which parser to use or let Rfm decide.

    Rfm.config :parser => :libxml

If you're not able to install one of the faster parsers, ginjo-rfm will fall back to
Ruby's built-in REXML. Want to roll your own XML adapter? Just pass it to Rfm as a module.

    Rfm.config :parser => MyHomeGrownAdapter

Choose your preferred parser globaly, as in the above example, or set a different parser for each model.
    
    class Order < Rfm::Base
      config :parser => :hpricot
    end
  
The current parsing options are

    :jdom         ->  JDOM (for JRuby)
    :oxsax        ->  Ox SAX
    :libxml       ->  LibXML Tree
    :libxmlsax    ->  LibXML SAX
    :nokogirisax  ->  Nokogiri SAX
    :nokogiri     ->  Nokogiri Tree
    :hpricot      ->  Hpricot Tree
    :rexml        ->  REXML Tree
    :rexmlsax     ->  REXML SAX
  

#### Configuration API

The ginjo-rfm configuration module lets you store your settings in several different ways. Store some, or all, of your project-specific settings in a rfm.yml file at the root of your project, or in your Rails config/ directory. Settings can also be put in a RFM_CONFIG constant at the top level of your project.  Configuration settings can be simple key=>values, or they can be named groups of key=>values. Configuration can also be passed to various Rfm methods during load and runtime, as individual settings or as groups.

rfm.yml

    :ssl: true
    :root_cert: false
    :timeout: 10
    :port: 443
    :host: live.mydomain.com
    :account_name: admin
    :password: pass
    :database: MyFmDb

Set a model's configuration.
  
    class MyModel < Rfm::Base
      config :layout => 'mylayout'
    end


#### Compound Filemaker Queries, with Omitable FMP Find Requests

Create a Filemaker 'omit' request by including an :omit key with a value of true.

    my_layout.find :field1 => 'val1', :field2 => 'val2', :omit => true

Create multiple Filemaker find requests by passing an array of hashes to the #find method.

    my_layout.find [{:field1 => 'bill', :field2 => 'admin'}, {:field2 => 'staff', :field3 => 'inactive', :omit => true}, ...]

If the value of a field in a find request is an array of strings, the string values will be logically OR'd in the query.

    my_layout.find :fieldOne => ['bill','mike','bob'], :fieldTwo =>'staff'


#### Full Metadata Support
  
* Server databases
* Database layouts
* Database scripts
* Layout fields
* Layout portals
* Resultset meta
* Field definition meta
* Portal definition meta

There are also many enhancements to make it easier to get the objects or data you want. Some examples:

Get a database object using default config

    Rfm.db 'my_db'

Get a layout object using config grouping :my_group
  
    Rfm.layout :my_group

Get the total count of all records in the table

    MyModel.total_count

Get the portal names (table-occurrence names) on the current layout

    MyModel.portal_names

Get the names of fields on the current layout

    my_record.field_names
  
  
### From Version 1.4.x

From ginjo-rfm 1.4.x, the following features are also included.

Connection timeout settings

    Rfm.config :timeout => 10

Value-list alternate display

    i = array_of_value_list_items[3]  # => '8765'
    i.value                           # => '8765'
    i.display                         # => '8765 Amy'



## Credits

Rfm was primarily designed by Six Fried Rice co-founder Geoff Coffey.

Other lead contributors:

* Mufaddal Khumri helped architect Rfm in the most Ruby-like way possible. He also contributed the outstanding error handling code and a comprehensive hierarchy of error classes.
* Atsushi Matsuo was an early Rfm tester, and provided outstanding feedback, critical code fixes, and a lot of web exposure.
* Jesse Antunes helped ensure that Rfm is stable and functional.
* Larry Sprock added ssl support, switched the xml parser to a much faster Nokogiri, added the rspec testing framework, and refined code architecture.
* William Richardson is the current maintainer of the ginjo-rfm fork and added support for multiple xml parsers, ActiveModel integration, field mapping, compound queries, logging, scoping, and a configuration framework.


