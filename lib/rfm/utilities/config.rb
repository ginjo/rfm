module Rfm
  #
  # Top level config hash accepts any defined config parameters,
  # or group-name keys pointing to config subsets.
  # The subsets can be any grouping of defined config parameters, as a hash.
  # See CONFIG_KEYS for defined config parameters.
  #
  module Config
    require 'yaml'
    require 'erb'

    CONFIG_KEYS = %w(
      file_name
      file_path
      parser
      host
      port
      proxy
      account_name
      password
      database
      layout
      ignore_bad_data
      ssl
      root_cert
      root_cert_name
      root_cert_path
      warn_on_redirect
      raise_on_401
      timeout
      log_actions
      log_responses
      log_parser
      use
      parent
      template
      grammar
      field_mapping
      capture_strings_with
      logger
      decimal_separator
    )

    CONFIG_DONT_STORE = %w(strings using parents symbols objects)  #capture_strings_with)

    extend self
    @config = {}

    # Set @config with args & options hash.
    # Args should be symbols representing configuration groups,
    # with optional config hash as last arg, to be merged on top.
    # Returns @config.
    #
    # == Sets @config with :use => :group1, :layout => 'my_layout'
    #    config :group1, :layout => 'my_layout
    #
    # Factory.server, Factory.database, Factory.layout, and Base.config can take
    # a string as the first argument, refering to the relevent server/database/layout name.
    #
    # == Pass a string as the first argument, to be used in the immediate context
    #    config 'my_layout'                     # in the model, to set model configuration
    #    Factory.layout 'my_layout', :my_group  # to get a layout from settings in :my_group
    #
    def config(*args, &block)
      @config ||= {}
      return @config if args.empty?
      config_write(*args, &block)
      @config
    end

    # Sets @config just as above config method, but clears @config first.
    def config_clear(*args)
      @config = {}
      return @config if args.empty?
      config_write(*args)
      @config
    end

    # Reads compiled config, including filters and ad-hoc configuration params passed in.
    # If first n parameters are strings, they will be appended to config[:strings].
    # If next n parameters are symbols, they will be used to filter the result. These
    # filters will override all stored config[:use] settings.
    # The final optional hash should be ad-hoc config settings.
    #
    # == Gets top level settings, merged with group settings, merged with local and ad-hoc settings.
    #    get_config :my_server_group, :layout => 'my_layout'  # This gets top level settings,
    #
    # == Gets top level settings, merged with local and ad-hoc settings.
    #    get_config :layout => 'my_layout
    #
    def get_config(*arguments)
      #puts caller_locations(1,1)[0]
      args = arguments.clone
      @config ||= {}
      options = config_extract_options!(*args)
      strings = options[:strings].rfm_force_array || []
      symbols = options[:symbols].rfm_force_array.concat(options[:hash][:use].rfm_force_array) || []
      objects = options[:objects].rfm_force_array || []

      rslt = config_merge_with_parent(symbols).merge(options[:hash])
      #using = rslt[:using].rfm_force_array
      sanitize_config(rslt, CONFIG_DONT_STORE, false)
      rslt[:using].delete ""
      rslt[:parents].delete ""
      rslt.merge(:strings=>strings, :objects=>objects)
    end

    def state(*args)
      return @_state if args.empty? && !@state.nil? && (RUBY_VERSION[0,1].to_i > 1 ? (caller_locations(1,1) == @_last_state_caller) : false)
      @_state = get_config(*args)
      (@_last_state_caller = caller_locations(1,1)) if RUBY_VERSION[0,1].to_i > 1
      @_state
    end

    def log
      Rfm.log
    end

    protected

    # Get or load a config file as the top-level config (above RFM_CONFIG constant).
    # Default file name is rfm.yml.
    # Default paths are '' and 'config/'.
    # File name & paths can be set in RFM_CONFIG and Rfm.config.
    # Change file name with :file_name => 'something.else'
    # Change file paths with :file_path => ['array/of/', 'file/paths/']
    def get_config_file
      @@config_file_data ||= (
        config_file_name = @config[:file_name] || (RFM_CONFIG[:file_name] rescue nil) || 'rfm.yml'
        config_file_paths = [''] | [(@config[:file_path] || (RFM_CONFIG[:file_path] rescue nil) || %w( config/ ./ ))].flatten
        config_file_paths.collect do |path|
          (YAML.load(ERB.new(File.read(File.join(path, config_file_name))).result) rescue {})
        end.inject({}){|h,a| h.merge(a)}
      ) || {}
    end

    # Get the top-level configuration from yml file and RFM_CONFIG
    def get_config_base
      get_config_file.merge((defined?(RFM_CONFIG) and RFM_CONFIG.is_a?(Hash)) ? RFM_CONFIG : {})
    end

    # Get the parent configuration object according to @config[:parent]
    def get_config_parent
      @config ||= {}
      case
      when @config[:parent].is_a?(String)
        eval(@config[:parent])
      when !@config[:parent].nil? && @config[:parent].is_a?(Rfm::Config)
        @config[:parent]
      else
        eval('Rfm::Config')
      end
    end

    # Merge args into @config, as :use=>[arg1, arg2, ...]
    # Then merge optional config hash into @config.
    # Pass in a block to use with parsed config in args.
    def config_write(*args)   #(opt, args)
      options = config_extract_options!(*args)
      options[:symbols].each{|a| @config.merge!(:use=>a.to_sym){|h,v1,v2| [v1].flatten << v2  }}
      @config.merge!(options[:hash]).reject! {|k,v| CONFIG_DONT_STORE.include? k.to_s}
      #options[:hash][:capture_strings_with].rfm_force_array.each do |label|
      @config[:capture_strings_with].rfm_force_array.each do |label|
        string = options[:strings].delete_at(0)
        (@config[label] = string) if string && !string.empty?
      end
      parent = (options[:objects].delete_at(0) || options[:hash][:parent])
      (@config[:parent] = parent) if parent
      yield(options) if block_given?
    end

    # Get composite config from all levels, processing :use parameters at each level
    def config_merge_with_parent(filters=nil)
      @config ||= {}

      # Get upstream compilation
      upstream = if (self != Rfm::Config)
        #puts [self, @config[:parent], get_config_parent].join(', ')
        get_config_parent.config_merge_with_parent
      else
        get_config_base
      end.clone

      upstream[:using] ||= []
      upstream[:parents] ||= ['file', 'RFM_CONFIG']

      filters = (@config[:use].rfm_force_array | filters.rfm_force_array).compact

      rslt = config_filter(upstream, filters).merge(config_filter(@config, filters))

      rslt[:using].concat((@config[:use].rfm_force_array | filters).compact.flatten)   #.join
      rslt[:parents] << @config[:parent].to_s

      rslt.delete :parent

      rslt || {}
      #     rescue
      #       puts "Config#config_merge_with_parent for '#{self.class}' falied with #{$1}"
    end

    # Returns a configuration hash overwritten by :use filters in the hash
    # that match passed-in filter names or any filter names contained within the hash's :use key.
    def config_filter(conf, filters=nil)
      conf = conf.clone
      filters = (conf[:use].rfm_force_array | filters.rfm_force_array).compact
      if (!filters.nil? && !filters.empty?)
        filters.each do |f|
          next unless conf[f]
          conf.merge!(conf[f] || {})
        end
      end
      conf.delete(:use)
      conf
    end

    # Extract arguments into strings, symbols, objects, hash.
    def config_extract_options!(*args)
      strings, symbols, objects = [], [], []
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each do |a|
        case
        when a.is_a?(String)
          strings << a
        when a.is_a?(Symbol)
          symbols << a
        else
          objects << a
        end
      end
      {:strings=>strings, :symbols=>symbols, :objects=>objects, :hash=>options}
    end

    # Remove un-registered keys from a configuration hash.
    # Keep should be a list of strings representing keys to keep.
    def sanitize_config(conf={}, keep=[], dupe=false)
      (conf = conf.clone) if dupe
      conf.reject!{|k,v| (!CONFIG_KEYS.include?(k.to_s) or [{},[],''].include?(v)) and !keep.include? k.to_s }
      conf
    end

  end # module Config

end # module Rfm
