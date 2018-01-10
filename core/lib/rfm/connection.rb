require 'net/https'
require 'cgi'
require 'rfm/compound_query'
#require 'rfm/config'
#require 'logger'

module Rfm
  class Connection
    using Refinements
    prepend Config
    
    # TODO: Make this autoload.
    require 'rexml/document'

    def initialize(host=nil, **opts)     #(action, params, request_options={},  *args)      
      host && config(host:host)
      
      # Set a default formatter if none exits.
      # Note that if rfm-model is loaded, it will have set the :formatter already at the Rfm::Config class level.
      if !config.has_key?(:formatter)
        case 
        when Kernel.const_defined?(:SaxChange)
          config parser: SaxChange::Parser.new(config)  # unless config[:parser]  ???
          config formatter: ->(io, options) do
            options[:parser].call(io, options)
          end          
        else 
          config formatter: ->(io, options){ REXML::Document.new(io) }
        end
      end
      
    end # initialize
    

    def log
      Rfm.log
    end

    def state(**opts)
      #@defaults.merge(super(**opts))
      #@defaults.merge(**opts)
      config.merge(**opts)
    end


    # Should all of these convenience getters exist?

    def host_name
      state[:host]
    end

    def scheme
      state[:ssl] ? "https" : "http"
    end

    def port
      state[:ssl] && state[:port].nil? ? 443 : state[:port]
    end
    
    def database
      state[:database]
    end
    
    def layout
      state[:layout]
    end
    
    def grammar
      state[:grammar]
    end
    
    # Field mapping is really a layout concern. Where should it go?
    # It is not a connection attribute, I don't think.
    # def field_mapping
    #   @field_mapping ||= load_field_mapping(state[:field_mapping])
    # end
    def field_mapping
      load_field_mapping(state[:field_mapping])
    end
    

    ###  COMMANDS  ###
    #
    #    :options parameter refers (usually) to request options other than query parameters, including but not limited to: result size limit, filemaker xml grammar, xml parser template (usually a name, spec, or object), query scope (I think? ... maybe not), etc.
    #
    #    Check 'gen_params' method before changing any param name or options name in these methods,
    #    with specific reference to '_database' and '_layout', but not limited to those params.
    #
    # Returns a ResultSet object containing _every record_ in the table associated with this layout.
    def findall(_layout=nil, **options)
      #return unless self.class.const_defined?(:ENABLE_FINDALL) && ENABLE_FINDALL || ENV['ENABLE_FINDALL']
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-findall', {}, options)
    end

    # Returns a ResultSet containing a single random record from the table associated with this layout.
    def findany(_layout=nil, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-findany', {}, options)
    end

    # Finds a record. Typically you will pass in a hash of field names and values. For example:
    def find(_layout=nil, find_criteria, **options )
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      find_criteria = {'-recid'=>find_criteria} if (find_criteria.to_s.to_i > 0)
      # Original (and better!) code for making this 'find' command compound-capable:
      get_records(*Rfm::CompoundQuery.new(find_criteria, options))
      # But then inserted this to stub 'find' to get it working for rfm v4 dev changes.
      #get_records('-find', find_criteria, options)
    end

    # Access to raw -findquery command.
    def query(_layout=nil, query_hash, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-findquery', query_hash, options)
    end

    # Updates the contents of the record whose internal +recid+ is specified.
    def edit(_layout=nil, recid, values, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-edit', {'-recid' => recid}.merge(values), options)
      #get_records('-edit', {'-recid' => recid}.merge(expand_repeats(values)), options) # attempt to set repeating fields.
    end

    # Creates a new record in the table associated with this layout.
    def create(_layout=nil, values, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-new', values, options)
    end

    # Deletes the record with the specified internal recid.
    def delete(_layout=nil, recid, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-delete', {'-recid' => recid}, options)
      
      # Do we really want to return nil? FMP XML API returns the original record.
      #return nil
    end

    # Retrieves metadata only, with an empty resultset.
    def view(_layout=nil, **options)
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      get_records('-view', {}, options)
    end

    # Get the foundset_count only given criteria & options.
    # TODO: This should probably be abstracted up to the Model layer of Rfm,
    # since it has no FMServer-specific command.
    def count(_layout=nil, find_criteria, **options)
      # foundset_count won't work until xml is parsed (still need to dev the xml parser interface to rfm v4).
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      options[:max_records] = 0
      find(find_criteria, **options).foundset_count   # from basic hash:  ['fmresultset']['resultset']['count'].to_i
    end
    
    def databases(**options)
      # This from factory.
      #c = Connection.new('-dbnames', {}, {:grammar=>'FMPXMLRESULT'}, @server)
      #c.parse('fmpxml_minimal.yml', {})['data'].each{|k,v| (self[k] = Rfm::Database.new(v['text'], @server)) if k.to_s != '' && v['text']}
      # We only need a basic array of strings, so the simplest way...
      #connect('-dbnames', {}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
      # But we want controll over grammer & parsing, so use get_records...
      options[:grammar] ||= 'FMPXMLRESULT'
      # Don't set this here. Try to use rfm-model to set it, if even needed at all.
      #options[:template] ||= :databases
      get_records('-dbnames', {}, options)
    end

    def layouts(**options)
      # #connect('-layoutnames', {"-db" => database}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
      # options[:database] ||= database
      # options[:grammar] ||= 'FMPXMLRESULT'
      # get_records('-layoutnames', {}, options)
      
      require 'rfm/layouts_cmd'
      Rfm::Commands::Layouts.new(self, **options).call
    end
    
    def layout_meta(_layout=nil, **options)
      #get_records('-view', gen_params(binding, {}), options)
      #connect('-view', gen_params(binding, {}), {:grammar=>'FMPXMLLAYOUT'}.merge(options)).body
      options[:database] ||= database
      options[:layout] = _layout || options[:layout] || layout
      options[:grammar] ||= 'FMPXMLLAYOUT'
      get_records('-view', {}, options)
    end
    
    def scripts(**options)
      #connect('-scriptnames', {"-db" => database}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
      options[:database] ||= database
      options[:grammar] ||= 'FMPXMLRESULT'
      # Don't set this here. Try to use rfm-model to set it, if even needed at all.
      #options[:template] ||= :databases
      get_records('-scriptnames', {}, options)
    end
    
    ###  END COMMANDS  ###


    def get_records(action, params = {}, runtime_options = {})
      #options[:template] ||= state[:template] # Dont decide template here!  #|| select_grammar('', options).to_s.downcase.to_sym
      
      runtime_options[:grammar] ||= 'fmresultset'  #select_grammar(post, request_options)      
      
      params, connection_options = prepare_params(params, runtime_options)
      
      # This has to be done after prepare_params, or database & layout options
      # get sent to 'connect' every time, which breaks 'databases', 'layouts', and 'scripts' commands.
      
      full_options = state(runtime_options).merge({connection:self})
      
      # Note the capture_resultset_meta call from rfm v3.
      #capture_resultset_meta(rslt) unless resultset_meta_valid? #(@resultset_meta && @resultset_meta.error != '401')

      # You could also use this without a block, and forgo http-to-sax-parser streaming.
      #   io = connect(action, params, options).body
      # The block enables streaming and returns whatever is ultimately returned from the yield,
      # the finished object tree from the formatter, in this case.
      # If you call connection_thread.value, you will get the finished connection response object,
      # but it will wait until thread is done, so it defeats the purpose of streaming to the io object.
      
      _formatter = full_options[:formatter]     #formatter(full_options)  # The formatter method has been removed in favor of @defaults[:formatter]
      
      #puts "Connection#get_records calling 'connect' with action: #{action}, params: #{params}, options: #{connection_options}"
      
      if block_given?
        connect(action, params, connection_options) do |io, connection_thread|
          yield(io, full_options.merge({http_thread:connection_thread, local_env:binding}))
        end
      elsif _formatter
        connect(action, params, connection_options) do |io, connection_thread|
          _formatter.call(io, full_options.merge({http_thread:connection_thread, local_env:binding}))
        end
      else
        connect(action, params, connection_options)
      end
      
      # As a side note, here's a way to pretty-print raw xml in ruby:
      # REXML::Document.new(xml_string).write($stdout, 2)

    end # get_records

    # TODO: Stop deleting options, just let them fall out of the way by expand_options method.
    def connect(action, params={}, request_options={})
      #grammar_option = request_options[:grammar]   #request_options.delete(:grammar)
      post = params.merge(expand_options(state(request_options))).merge({action => ''})
      grammar = select_grammar(post, request_options)
      host = request_options[:host] || host_name   #request_options.delete(:host) || host_name
      
      # The block will be yielded with an io_reader and a connection object,
      # after the http connection has begun in its own thread.
      # See http_fetch method.
      if block_given?
        http_fetch(host, port, "/fmi/xml/#{grammar}.xml", state[:account_name], state[:password], post, &Proc.new)
      else
        http_fetch(host, port, "/fmi/xml/#{grammar}.xml", state[:account_name], state[:password], post)
      end
    end
    

    private

    def http_fetch(host_name, port, path, account_name, password, post_data, limit=10)
      raise Rfm::CommunicationError.new("While trying to reach the Web Publishing Engine, RFM was redirected too many times.") if limit == 0

      if state[:log_actions] == true
        #qs = post_data.collect{|key,val| "#{CGI::escape(key.to_s)}=#{CGI::escape(val.to_s)}"}.join("&")
        qs_unescaped = post_data.collect{|key,val| "#{key.to_s}=#{val.to_s}"}.join("&")
        #warn "#{@scheme}://#{@host_name}:#{@port}#{path}?#{qs}"
        log.info "#{scheme}://#{host_name}:#{port}#{path}?#{qs_unescaped}"
      end

      request = Net::HTTP::Post.new(path)
      request.basic_auth(account_name, password)
      request.set_form_data(post_data)

      if state[:proxy]
        connection = Net::HTTP::Proxy(*state[:proxy]).new(host_name, port)
      else
        connection = Net::HTTP.new(host_name, port)
      end
      #ADDED LONG TIMEOUT TIMOTHY TING 05/12/2011
      connection.open_timeout = connection.read_timeout = state[:timeout]
      if state[:ssl]
        connection.use_ssl = true
        if state[:root_cert]
          connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
          connection.ca_file = File.join(state[:root_cert_path], state[:root_cert_name])
        else
          connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      # Stream to IO pipe, if block given.
      # See: https://www.jstorimer.com/blogs/workingwithcode/7766091-introduction-to-ipc-in-ruby
      if block_given?
        #puts "Connection#http_fetch (with block)"
        #pipe_reader, pipe_writer = IO.pipe
        IO.pipe do |pipe_reader, pipe_writer|
          #@io_object = [pipe_reader, pipe_writer]
          thread = Thread.new do
            #pipe_reader.close # close the unused reader if forking.
            # I don't think we need the Thread.handle_interrupt,
            # the thread.abort_on_exception seems to work well.
            #Thread.handle_interrupt(Exception => :immediate) do
              begin
                connection.request request do |response|
                  check_for_http_errors response
      
                  # This is NET::HTTP's way of streaming the response body.
                  # Note that the response object already has the header information at this point.
                  response.read_body do |chunk|
                    if chunk.size > 0
                      bytes = pipe_writer.write(chunk) 
                      Rfm.log.info("#{self} wrote #{bytes} bytes to IO pipe.") if state[:log_responses]
                    end
                  end
                  
                  #pipe_writer.close # close writer here if using Thread.
                end # connection.request
              ensure
                Rfm.log.info("#{self} ensurring IO-writer is closed.") if state[:log_responses]
                pipe_writer.close
              end
            #end # Thread.interrupt
          end # Thread
          thread.abort_on_exception = true
          #pipe_writer.close # close unused writer if using Fork.
          
          # Hand over the reader IO and thread to the block.
          # Note that thread.value will give the return value of thread,
          # but only after the thread has closed. So beware how you use 'thread'.
          yield(pipe_reader, thread)
        end
      else
        # Give straight response object, if no block given.
        puts "Connection.http_fetch (without block)"
        response = connection.start { |http| http.request(request) }
        check_for_http_errors(response)
        response
      end
    end # http_fetch
    
    def check_for_http_errors(response)
      if nil && state[:log_responses] == true
        response.to_hash.each { |key, value| log.info "#{key}: #{value}" }
        # TODO: Move this to http connection block.
        #log.info response.body
      end
    
      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPRedirection
        if state[:warn_on_redirect]
          log.warn "The web server redirected to " + response['location'] + 
            ". You should revise your connection hostname or fix your server configuration if possible to improve performance."
        end
        newloc = URI.parse(response['location'])
        http_fetch(newloc.host, newloc.port, newloc.request_uri, account_name, password, post_data, limit - 1)
      when Net::HTTPUnauthorized
        msg = "The account name or password provided is not correct (or the account doesn't have the fmxml extended privilege)."
        raise Rfm::AuthenticationError.new(msg)
      when Net::HTTPNotFound
        msg = "Could not talk to FileMaker because the Web Publishing Engine is not responding (server returned 404)."
        raise Rfm::CommunicationError.new(msg)
      else
        msg = "Unexpected response from server: #{response.code} (#{response.class.to_s}). Unable to communicate with the Web Publishing Engine."
        raise Rfm::CommunicationError.new(msg)
      end
    end
    
    #def check_for_errors(code=@meta['error'].to_i, raise_401=state[:raise_401])
    def check_for_errors(code=nil, raise_401=state[:raise_401])
      Rfm.log.warn("#{self} No response code given in check_for_errors.") unless code
      code = (code || 0).to_i
      #puts ["\nRESULTSET#check_for_errors", code, raise_401]
      raise Rfm::Error.getError(code) if code != 0 && (code != 401 || raise_401)
    end

    def load_field_mapping(mapping={})
      mapping = (mapping || {}) #.to_cih
      def mapping.invert
        super #.to_cih
      end
      mapping
    end
    
    # Clean up passed params & options.
    # This method does not fill in missing FMS api params or options,
    # but it may fill in Rfm params and options... Hmmm, it really should not.
    def prepare_params(params={}, options={})
      params, options = params.dup, options.dup
      _database = options[:database] #options.delete(:database)
      _layout   = options[:layout]   #options.delete(:layout)
      if params.is_a?(String)
        params = Hash[URI.decode_www_form(params)]
      end
      params['-db'] = _database if _database
      params['-lay'] = _layout if _layout
      
      #options[:field_mapping] = field_mapping.invert if field_mapping && !options[:field_mapping]
      #mapping = options.extract(:field_mapping) || field_mapping
      mapping = options[:field_mapping] || field_mapping
      apply_field_mapping!(params, mapping.invert) if mapping.is_a?(Hash)
      
      [params, options]
    end
    
    def apply_field_mapping!(params, mapping)
      params.dup.each_key do |k|
        new_key = mapping[k.to_s] || k
        if params[new_key].is_a? Array
          params[new_key].each_with_index do |v, i|
            params["#{new_key}(#{i+1})"]=v
          end
          params.delete new_key
        else
          params[new_key]=params.delete(k) if new_key != k
        end
        #puts "PRMS: #{new_key} #{params[new_key].class} #{params[new_key]}"
      end
    end

    def select_grammar(post, options={})
      grammar = state(options)[:grammar] || 'fmresultset'
      if grammar.to_s.downcase == 'auto'
        # TODO: build grammar-decider here.
        return "fmresultset"
        # post.keys.find(){|k| %w(-find -findall -dbnames -layoutnames -scriptnames).include? k.to_s} ? "FMPXMLRESULT" : "fmresultset"   
      else
        grammar
      end
    end

    def expand_options(options)
      result = {}
      #field_mapping = options.delete(:field_mapping) || {}
      _field_mapping = options.delete(:field_mapping) || {}
      options.each do |key,value|
        case key.to_sym
        when :max_portal_rows
          result['-relatedsets.max'] = value
          result['-relatedsets.filter'] = 'layout'
        when :ignore_portals
          result['-relatedsets.max'] = 0
          result['-relatedsets.filter'] = 'layout'
        when :max_records
          result['-max'] = value
        when :skip_records
          result['-skip'] = value
        when :sort_field
          if value.kind_of? Array
            raise Rfm::ParameterError.new(":sort_field can have at most 9 fields, but you passed an array with #{value.size} elements.") if value.size > 9
            value.each_index { |i| result["-sortfield.#{i+1}"] = _field_mapping[value[i]] || value[i] }
          else
            result["-sortfield.1"] = _field_mapping[value] || value
          end
        when :sort_order
          if value.kind_of? Array
            raise Rfm::ParameterError.new(":sort_order can have at most 9 fields, but you passed an array with #{value.size} elements.") if value.size > 9
            value.each_index { |i| result["-sortorder.#{i+1}"] = value[i] }
          else
            result["-sortorder.1"] = value
          end
        when :post_script
          if value.class == Array
            result['-script'] = value[0]
            result['-script.param'] = value[1]
          else
            result['-script'] = value
          end
        when :pre_find_script
          if value.class == Array
            result['-script.prefind'] = value[0]
            result['-script.prefind.param'] = value[1]
          else
            result['-script.presort'] = value
          end
        when :pre_sort_script
          if value.class == Array
            result['-script.presort'] = value[0]
            result['-script.presort.param'] = value[1]
          else
            result['-script.presort'] = value
          end
        when :response_layout
          result['-lay.response'] = value
        when :logical_operator
          result['-lop'] = value
        when :modification_id
          result['-modid'] = value
        else
          if state.keys.member?(key.to_sym)
            state(key.to_sym=>value)
          else
            if state[:raise_on_invalid_option]
              raise Rfm::ParameterError.new("Invalid option: #{key} (are you using a string instead of a symbol?)")
            end
          end
        end
      end
      return result
    end
    
    # # Experimental open-uri, was in http_fetch method.
    # # This works well but writes entire http response body to temp file.
    # require 'open-uri'
    # output=[]
    # open("#{scheme}://#{host_name}:#{port}#{path}?#{qs_unescaped}",
    #   ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
    #   http_basic_authentication: [account_name, password]
    # ) do |io|
    #   output << io
    #   yield(io)
    # end
    # return output[0]
    
  end # Connection


end # Rfm
