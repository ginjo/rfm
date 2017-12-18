# Connection object takes over the communication functionality that was previously in Rfm::Server.
# TODO: Clean up the way :grammar is sent in to the initializing method.
#       Currently, the actual connection instance config doesn't get set with the correct grammar,
#       even if the http_fetch is using the correct grammar.

require 'net/https'
require 'cgi'
#require 'rfm/config'
require 'logger'

module Rfm
  class Connection
    #include Config

    def initialize(host, **opts)     #(action, params, request_options={},  *args)
      #config(**opts)
      
      # New from WBR, maybe temp.
      @logger = Logger.new($stdout)

      @defaults = {
        :host => host || 'localhost',
        :port => nil,
        :proxy=>false,  # array of (p_addr, p_port = nil, p_user = nil, p_pass = nil)
        :ssl => true,
        :root_cert => true,
        :root_cert_name => '',
        :root_cert_path => '/',
        :account_name => '',
        :password => '',
        :log_actions => false,
        :log_responses => false,
        :log_parser => false,
        :warn_on_redirect => true,
        :raise_on_401 => false,
        :timeout => 60,
        :ignore_bad_data => false,
        :template => :fmresultset,
        :grammar => 'fmresultset'
      } .merge(opts)
    end
    
    def log
      @logger
    end

    def state(**opts)
      #@defaults.merge(super(**opts))
      @defaults.merge(**opts)
    end

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

    def connect(action, params={}, request_options={})
      grammar_option = request_options.delete(:grammar)
      post = params.merge(expand_options(request_options)).merge({action => ''})
      grammar = select_grammar(post, :grammar=>grammar_option)
      http_fetch(host_name, port, "/fmi/xml/#{grammar}.xml", state[:account_name], state[:password], post)
    end

    def select_grammar(post, options={})
      grammar = state(options)[:grammar] || 'fmresultset'
      if grammar.to_s.downcase == 'auto'
        # TODO: Build grammar parser in new sax engine templates to handle FMPXMLRESULT.
        return "fmresultset"
        # post.keys.find(){|k| %w(-find -findall -dbnames -layoutnames -scriptnames).include? k.to_s} ? "FMPXMLRESULT" : "fmresultset"   
      else
        grammar
      end
    end

    def parse(template=nil, initial_object=nil, parser=nil, options={})
      template ||= state[:template]
      #(template =  'fmresultset.yml') unless template
      #(template = File.join(File.dirname(__FILE__), '../sax/', template)) if template.is_a? String
      Rfm::SaxParser.parse(connect.body, template, initial_object, parser, state(*options)).result
    end


    ###  COMMANDS  ###
    #
    #    :options parameter refers (usually) to request options other than query parameters, including but not limited to: result size limit, filemaker xml grammar, xml parser template (usually a name, spec, or object), query scope (I think? ... maybe not), etc.
    #
    #    Check 'gen_params' method before changing any param name or options name in these methods,
    #    with specific reference to '_database' and '_layout', but not limited to those params.
    #
    # Returns a ResultSet object containing _every record_ in the table associated with this layout.
    def findall(options = {})
      return unless const_defined(:ENABLE_FINDALL) && ENABLE_FINDALL
      get_records('-findall', {}, options)
    end

    # Returns a ResultSet containing a single random record from the table associated with this layout.
    def findany(_layout=nil, _database=nil, **options)
      get_records('-findany', gen_params(binding), options)
    end

    # Finds a record. Typically you will pass in a hash of field names and values. For example:
    def find(_layout=nil, _database=nil, find_criteria, **options )
      #puts "layout.find-#{self.object_id}"
      options.merge!({:field_mapping => field_mapping.invert}) if field_mapping
      # Original (and better!) code for making this 'find' command compound-capable:
      #get_records(*Rfm::CompoundQuery.new(find_criteria, options))
      # But then inserted this to stub 'find' to get it working for rfm v4 dev changes.
      get_records('-find', gen_params(binding, find_criteria), options)
    end

    # Access to raw -findquery command.
    def query(query_hash, options = {})
      get_records('-findquery', query_hash, options)
    end

    # Updates the contents of the record whose internal +recid+ is specified.
    def edit(recid, values, options = {})
      get_records('-edit', {'-recid' => recid}.merge(values), options)
      #get_records('-edit', {'-recid' => recid}.merge(expand_repeats(values)), options) # attempt to set repeating fields.
    end

    # Creates a new record in the table associated with this layout.
    def create(values, options = {})
      get_records('-new', values, options)
    end

    # Deletes the record with the specified internal recid.
    def delete(recid, options = {})
      get_records('-delete', {'-recid' => recid}, options)
      return nil
    end

    # Retrieves metadata only, with an empty resultset.
    def view(_layout=nil, _database=nil, **options)
      get_records('-view', gen_params(binding, {}), options)
    end

    # Get the foundset_count only given criteria & options.
    def count(_layout=nil, _database=nil, find_criteria, **options)
      # This won't work until xml is parsed (still need to dev the xml parser interface to rfm v4).
      find( gen_params(binding, find_criteria), options.merge({:max_records => 0}) ).foundset_count
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

      #c = Connection.new(action, prms, options, self)
      c = connect(action, prms, options)
      #rslt = c.parse(template, Rfm::Resultset.new(self, self))
      rslt = c.body
      #capture_resultset_meta(rslt) unless resultset_meta_valid? #(@resultset_meta && @resultset_meta.error != '401')
      rslt
    end

    def params(_database=nil, _layout=nil)
      {"-db" => (_database || database), "-lay" => (_layout || layout)}
    end
    
    # This is a new version of 'params' for rfm v4
    def gen_params(_binding, **opts)
      _database = _binding.local_variable_get(:_database)
      _layout = _binding.local_variable_get(:_layout)
      {"-db" => (_database || database), "-lay" => (_layout || layout), **opts}
    end
        
    # def load_layout
    #   #@loaded = true # This is first so parsing call to 'meta' wont cause infinite loop,
    #   # but I changed parsing template to refer directly to inst var instead of accessor method.
    #   connection = Connection.new('-view', {'-db' => state[:database], '-lay' => name}, {:grammar=>'FMPXMLLAYOUT'}, self)
    #   begin
    #     connection.parse(:fmpxmllayout, self)
    #     @loaded = true
    #   rescue
    #     @meta.clear
    #     raise $!
    #   end
    #   @meta
    # end

    def check_for_errors(code=@meta['error'].to_i, raise_401=state[:raise_401])
      #puts ["\nRESULTSET#check_for_errors", code, raise_401]
      raise Rfm::Error.getError(code) if code != 0 && (code != 401 || raise_401)
    end

    def field_mapping
      @field_mapping ||= load_field_mapping(state[:field_mapping])
    end
    
    def load_field_mapping(mapping={})
      mapping = (mapping || {}) #.to_cih
      def mapping.invert
        super #.to_cih
      end
      mapping
    end

    def databases(options={})
      # This from factory.
      #c = Connection.new('-dbnames', {}, {:grammar=>'FMPXMLRESULT'}, @server)
      #c.parse('fmpxml_minimal.yml', {})['data'].each{|k,v| (self[k] = Rfm::Database.new(v['text'], @server)) if k.to_s != '' && v['text']}
      # We only need a basic array of strings, so the simplest way...
      connect('-dbnames', {}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
    end

    def layouts(_database=nil, **options)
      connect('-layoutnames', {"-db" => database}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
    end
    
    def layout_meta(_layout=nil, _database=nil, **options)
      #get_records('-view', gen_params(binding, {}), options)
      connect('-view', gen_params(binding, {}), {:grammar=>'FMPXMLLAYOUT'}.merge(options)).body
    end
    
    def scripts(_database=nil, **options)
      connect('-scriptnames', {"-db" => database}, {:grammar=>'FMPXMLRESULT'}.merge(options)).body
    end
    
    
    ###  END COMMANDS  ###



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

      response = connection.start { |http| http.request(request) }
      if state[:log_responses] == true
        response.to_hash.each { |key, value| log.info "#{key}: #{value}" }
        log.info response.body
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
        msg = "The account name (#{account_name}) or password provided is not correct (or the account doesn't have the fmxml extended privilege)."
        raise Rfm::AuthenticationError.new(msg)
      when Net::HTTPNotFound
        msg = "Could not talk to FileMaker because the Web Publishing Engine is not responding (server returned 404)."
        raise Rfm::CommunicationError.new(msg)
      else
        msg = "Unexpected response from server: #{response.code} (#{response.class.to_s}). Unable to communicate with the Web Publishing Engine."
        raise Rfm::CommunicationError.new(msg)
      end
    end

    def expand_options(options)
      result = {}
      field_mapping = options.delete(:field_mapping) || {}
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
            value.each_index { |i| result["-sortfield.#{i+1}"] = field_mapping[value[i]] || value[i] }
          else
            result["-sortfield.1"] = field_mapping[value] || value
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
            raise Rfm::ParameterError.new("Invalid option: #{key} (are you using a string instead of a symbol?)")
          end
        end
      end
      return result
    end  

  end # Connection


end # Rfm
