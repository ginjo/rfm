# Changelog

## Ginjo-Rfm 3.0.12

* Make decimal separator configurable, as FM-Server uses local number settings in result set.
  Use configuration option `:decimal_separator`.

* Fix broken spec for Ox sax parser.

* Change dependency constraint for rspec to >= v2.


## Ginjo-Rfm 3.0.11

* Scoping fixes, changes, additions:

  Now takes proc or array of hashes or hash.

  Scope_args for scope proc now defaults to model instance.

  Now handles omits - puts them at end of request array.

* Support for rom-fmp 0.0.4 - query chaining with compound fm queries.

* Basic support for portal field writes.

        record['my_relationship::my_field.0'] = 'Adds a new portal record with data for my_field, if auto-create enabled'
        record.update_attributes! 'my_relationship::my_field.3' => 'Updates my_field in 3rd portal record, if exists'

* Fix Base#save! to store raised exceptions in errors, if possible.

* Fix CompoundQuery to handle nil values in query params.


## Ginjo-Rfm 3.0.10

* Fixed bug where missing metadata would cause errors when creating/editing records.

* Added scoping support

        scope = {:person_id => current_user.person_id}
        Order.find([{:status => ['open', 'processing']}, {:omit => true, :item_count => "<1"}], :scope => scope)
    
        class Orders < Rfm::Base
          SCOPE = Proc.new { {:expired => "=" } }
        end
        Order.find({:user_id => '12345'})
    
        class Orders < Rfm::Base
          SCOPE = Proc.new {|args| {:user_id => args} }
        end
        Order.find([{:status => ['open', 'processing']}, {:omit => true, :item_count => "<1"}], :scope_args => current_user.id)

* Code cleanup

## Ginjo-Rfm 3.0.9

* Fixed bug in parser that was appending each portal array recursively to itself.

* Sax parser template option :template now takes a full-path string.

* Compatible with dm-filemaker-adapter (for DataMapper ORM).

* Config now recognizes :template option, allowing alternative parsing templates.

## Ginjo-Rfm 3.0.8

* Implemented proxy option for database connections thru a proxy server.

        config :proxy=>['my.proxy.com', 8888]

* Implemented erb parsing of config.yml

* Disabled ```:grammar => :auto``` option. The current xml parser cannot yet use the FMPXMLRESULT grammar for general queries.


## Ginjo-Rfm 3.0.7

* Changed record creation so that generic records created from non-modelized layouts will be instances of Rfm::Record, instead of instances of a transient model class based on the layout. Transient model classes will foul up serialization and any number of other things. Records created from a user-defined model class will continue to be instances of the model class.

        my_layout.find(12345).class  ==  Rfm::Record
        MyModel.find(12345).class    ==  MyModel


## Ginjo-Rfm 3.0.6

* Fixed duplicate portal-name merging, added specs to test this.
* Minor updates to gem maintenance & release tools.

## Ginjo-Rfm 3.0.5

* Fixed parser handling of ```<field>``` element that's missing a ```<data>``` element.
* Fixed coercion of repeating field data.
* Fixed case where special characters in Filemaker data yielded array instead of string (sax parsing split text).
* Fixed various bugs in metadata parsing.
* Detached resultset from Rfm::MetaData::Field instance, now attaching only ResultsetMeta to Field.
* Fixed ruby-prof rake task.
* Updated deprecated rspec 2 specs, will now work with rspec 2 or 3.
* Added more specs for some recently found bugs and for sax parser.
* Fixed broken ActiveModel Lint specs in Ruby 2.1.
* General refinements & cleanup.
* Optimizations to sax_parser.
* Fixed typo in field.rb that was causing bugs.

## Ginjo-Rfm 3.0.4

* Corrected reference to @meta in fmpxmllayout.yml. Specs now passing for Layout#load\_layout.
* Added error checking to Layout#load\_layout.
* Fixed setting/saving of repeating fields. Added spec to verify.
* Fixed rspec rake task, fixed rake spec\_multi.
* Changed Ox default parse option to not encode special characters. This is now in tune with other parsers' defaults.
  This fixes (among other things) URLs returned from container fields.
* Fixed error in gemspec preventing sax templates from being included in gem build.

## Ginjo-Rfm 3.0.0

* Disabled default port in Connection (was 80), as it was tripping up connections where the port wasn't specified for a :use\_ssl connection on older Rubies.
* Fixes to :ignore\_portals option.
* Removed runtime dependency on activesupport from gemspec.
* Added check in Field#coerce to make sure a '?' is in a string before splitting on '?'. This was breaking repeating container fields.
* Fixed case mismatch in hash key in Factory classes. Added logging of parsing template to logging of parsing backend.
* Fixed bug in field\_control#value\_list.
* Added layout\_meta and resultset\_meta objects.
* Added fmpxmlresult.xml.builder for future use.
* Added Rfm.logger, Rfm.logger=, Config.logger, Config#logger, and config(:logger=>(...)).
* Added logging facility.
* Moved #state method from individual classes to Config class.
* Fixes to Base#update\_attributes.
* Refined multiple :use handling in Config.
* Using rspec 2
* Removed SubLayout.
* Record.new now automatically creats models based on layout name. Should there be an option to disable this?
* Removed ActiveSupport requirement (of course, ActiveSupport will load if ActiveModle is used, but that is the users' choice).
* Removed XmlMini, XmlParser, and related code & specs.
* Detached resultset from record, so record doesn't drag resultset around with it.
* Disabled automatic model creation from a table-name in a new Rfm::Record when initializing.
* Consolidated Base.new, Base#inititalize into Rfm::Record.
* Fixed validation callbacks issue.
* Fixed: Resultset will politely return [] when asked for non-existent portal\_names.
* Mods to rakefile benchmarking/profiling.
* Refactored Resultset metadata methods.
* Refactored Layout metadata methods.
* Fixed bug in Config#get\_config\_file where a single file path might not be recognized.
* Added connection.rb and moved some methods from Server to Connection.
* Sax parsing rewrite.

## Ginjo-Rfm 2.1.7

* Added field\_mapping awareness to :sort\_field query option.
* Relaxed requirement that query option keys be symbols - can now be strings.

## Ginjo-Rfm 2.1.6

* Fixed typo in Rfm::Record#[]=
* Fixed bug where valid? was called on models without ActiveModel::Validations being loaded.
* Fixed bug where Rfm::Base#reload wasn't clearing mods.

## Ginjo-Rfm 2.1.5

* Fixed bug preventing validation callbacks from running.

## Ginjo-Rfm 2.1.4

* Fixed bug where nil value list would raise exception.

## Ginjo-Rfm 2.1.3

* Fixed bug when loading layout metadata where value lists or field controls with only 1 item would throw an error.

## Ginjo-Rfm 2.1.2

* Fixed config.rb so that :file\_path (to user-defined yml config file) can be specified as a single path string
  or as an array of path strings.

## Ginjo-Rfm 2.1.1

* Bug fixes

* Specs passing in Ruby 1.8.7, 1.9.2.

## Ginjo-Rfm 2.1.0

* Removed ```:include_portals``` query option in favor of ```:ignore_portals```.

* Added ```:max_portal_rows``` query option.

* Added field-remapping framework to allow model fields with different names than Filemaker fields.

* Fix date/time/timestamp translations when writing data to Filemaker.

* Detached new Server objects from Factory.servers hash, so wont reuse or stack-up servers.

* Added grammar translation layer between xml parser and Rfm, allowing all supported xml grammars to be used with Rfm.
  This will also streamline changes/additions to Filemaker's xml grammar(s).

* Fixed case statement for ruby 1.9

* Configuration ```:use``` option now works for all Rfm objects that respond to ```config```.

## Ginjo-Rfm 2.0.2

* Added configuration parameter ignore\_bad\_data to silence data mismatch errors when loading resultset into records.

* Added method to load a resultset from file or string. Rfm::Resultset.load\_data(file\_or\_string).

* Added more specs for the above features and for the XmlParser module.

## Ginjo-Rfm 2.0.1

* Fixed bug in Base.find where options weren't being passed to Layout#find correctly.

* Fixed bug in rfm.rb when calling #models or #modelize.

## Ginjo-Rfm 2.0.0

* ActiveModel compatibility allows Rails ActiveRecord-style models.

* Alternative XML parsers using ActiveSupport::XmlMini interface.

* Compound queries with multiple omitable find-requests.

* Configuration API manages settings of multiple server/db/layout/etc setups.

* Full Filemaker metadata support.

## Ginjo-Rfm 1.4.4

* Fixed bug when creating empty value list.

* Additional fixes for Rfm::VERSION.

* Fixed Record getter/setter issue.

* Other minor fixes and cleanup.

* Added tests to rspec.

* Documentation cleanup.

## Ginjo-Rfm 1.4.3

* Fixed version management issue. Rfm::VERSION now works.

## Ginjo-Rfm 1.4.2

* Re-implemented:  

  Layout#field\_controls

  Layout#value\_lists  

* Enhanced:  

  ValueListItem handles both display & data items now.

  Timeout feature from timting (github/timting/rfm).

  Added specs for Record#save.  

* Fixed:  

  [Bug] Getting & setting fields with symbol-based keys was producing error.

  [Bug] Setting fields would not update main record hash.

  [Bug] Record#save wasn't merging back into self.  

* Partial Fix:  

  server.db.all
  db.layout.all
  db.script.all  

  Note: the "#all" method returns object names (as keys) only. The receiver of the method maintains the full object collection.  

  Example:  

    server.db.all #=> ['dbname1', 'dbname2', ...]
    server.db     #=> a DbFactory object (descendant of Hash), containing 0 or more Database objects

## Lardawge-Rfm 1.4.2 (unreleased)

* Made nil default on fields with no value.  

  Example:
 
        Old: record.john #=> "" 
        New: record.john #=> nil

## Lardawge-Rfm 1.4.1.2

* [Bug] Pointing out why testing is soooooo important when refactoring... Found a bug in getter/setter method in Rfm::Record (yes, added spec for it).

## Lardawge-Rfm 1.4.1.1

* [Bug] Inadvertently left out an attr\_reader for server from resultset effecting container urls.

## Lardawge-Rfm 1.4.1*

* Changed Server#do\_action to Server#connect.

* XML Parsing is now done via xpath which significantly speeds up parsing.

* Changes to accessor method names for Resultset#portals Resultset#fields to Resultset#portal\_meta and Resultset#field\_meta to better describe what you get back.

* Added an option to load portal records which defaults to false. This significantly speeds up load time when portals are present on the layout.

  Example:  

        result = fm_server('layout').find({:username => "==#{username}"}, {:include_portals => true})
        # => This will fetch all records with portal records attached.
    
        result.first.portals
        # => would return an empty hash by default.

* Internal file restructuring. Some classes have changed but it should be nothing a developer would use API wise. Please let me know if it is.

* Removed Layout#value\_lists && Layout#field\_controls. Will put back in if the demand is high. Needs a major refactor and different placement if it goes back in. Was broken so it didn't seem to be used by many devs.