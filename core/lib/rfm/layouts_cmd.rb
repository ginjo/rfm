###  Experimental classes for Rfm commands  ###

module Rfm
  module Commands
  
    # TODO: This is kinda messy. It might be overkill, but it would provide an API for user-modifyable commands.
    # Should it be a class or an instance at the connection level?
    # Where should command's default options be stored?
    # How should devs and users access this to modify it?
    # What concerns are separated into this class & does it make sense?
    class Layouts
      singleton_class.send :attr_accessor, :name, :main_call, :last_call, :options
      @name      = 'layouts'
      @main_call = proc {|connection, **options| connection.get_records('-layoutnames', {}, options) }
      @options = {
        database:  ->(connection){connection.config[:database]},
        grammar:   'FMPXMLRESULT',
        # Don't set this here. Try to use rfm-model to set it, if even needed at all.
        #template:  'databases.yml'
      }
      
      
      def call
        self.class.main_call.call(@connection, **@options)
      end
      
      def initialize(_connection=self, **options)
        @connection = _connection
        @options = self.class.options.merge(options)
        if @options[:database].is_a?(Proc)
          @options[:database] = @options[:database].call(@connection)
        end
      end
    end
    
  end
end



#     def layouts(**options)
#       #connect('-layoutnames', {"-db" => database}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
#       options[:database] ||= database
#       options[:grammar] ||= 'FMPXMLRESULT'
#       get_records('-layoutnames', {}, options)
#     end