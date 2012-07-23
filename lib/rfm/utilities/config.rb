module Rfm

  	# Should these go in Rfm module?
  	CONFIG_KEYS = %w(
			file_name
			file_path
			parser
			host
			port
			account_name
			password
			database
			layout
			converters
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
			grammar
		)
		
		CONFIG_DONT_STORE = %w(strings using parents symbols objects)

	# Top level config hash accepts any defined config parameters,
	# or group-name keys pointing to config subsets.
	# The subsets can be any grouping of defined config parameters, as a hash.
	# See CONFIG_KEYS for defined config parameters.
	#
  module Config
  	require 'yaml'
  	
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
	  	opt = args.rfm_extract_options!
	  	@config ||= {}
			config_write(opt, args, &block)
			@config
	  end
	  
	  # Sets @config just as above config method, but clears @config first.
	  def config_clear(*args)
	  	opt = args.rfm_extract_options!
	  	@config = {}
			config_write(opt, args)
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
  		args = arguments.clone
  		@config ||= {}
  		opt = args.rfm_extract_options!
  		strings = opt[:strings].rfm_force_array || []
  		symbols = opt[:use].rfm_force_array || []
  		objects = opt[:objects].rfm_force_array || []
  		args.each do |arg|
  			case true
  			when arg.is_a?(String) ; strings << arg
  			when arg.is_a?(Symbol) ; symbols << arg
  			else objects.unshift arg
  			end
  		end

			rslt = config_merge_with_parent(symbols).merge(opt)
			#using = rslt[:using].rfm_force_array
			sanitize_config(rslt, CONFIG_DONT_STORE, false)
			rslt[:using].delete ""
			rslt[:parents].delete ""
			rslt.merge(:strings=>strings, :objects=>objects)
  	end
  	
  	# Keep should be a list of strings representing keys to keep.
  	def sanitize_config(conf={}, keep=[], dupe=false)
  		(conf = conf.clone) if dupe
  		conf.reject!{|k,v| (!CONFIG_KEYS.include?(k.to_s) or [{},[],''].include?(v)) and !keep.include? k.to_s }
  		conf
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
				config_file_paths = [''] | (@config[:file_path] || (RFM_CONFIG[:file_path] rescue nil) || %w( config/ ))
				config_file_paths.collect do |f|
					(YAML.load_file("#{f}#{config_file_name}") rescue {})
				end.inject({}){|h,a| h.merge(a)}
			) || {}
		end
	  
	  
		# Merge args into @config, as :use=>[arg1, arg2, ...]
		# Then merge optional config hash into @config.
		# Pass in a block to use with strings in args. See base.rb.
	  def config_write(opt, args)
	  	strings = []; while args[0].is_a?(String) do; strings << args.shift; end
	  	args.each{|a| @config.merge!(:use=>a.to_sym)}
	  	@config.merge!(opt).reject! {|k,v| CONFIG_DONT_STORE.include? k.to_s}
	  	yield(strings) if block_given?
	  end
	  	
	  # Get composite config from all levels, processing :use parameters at each level
	  def config_merge_with_parent(filters=nil)
      remote = if (self != Rfm::Config) 
      	eval(@config[:parent] || 'Rfm::Config').config_merge_with_parent rescue {}
      else
      	get_config_file.merge((defined?(RFM_CONFIG) and RFM_CONFIG.is_a?(Hash)) ? RFM_CONFIG : {})
      end.clone
      
      remote[:using] ||= []
      remote[:parents] ||= ['file', 'RFM_CONFIG']

			filters = (@config[:use].rfm_force_array | filters.rfm_force_array).compact
			rslt = config_filter(remote, filters).merge(config_filter(@config, filters))
			
			rslt[:using].concat((@config[:use].rfm_force_array | filters).compact.flatten)   #.join
			rslt[:parents] << @config[:parent].to_s
			
			rslt.delete :parent
			
			rslt
    end
     
		# Returns a configuration hash overwritten by :use filters in the hash
		# that match passed-in filter names or any filter names contained within the hash's :use key.
		def config_filter(conf, filters=nil)
			conf = conf.clone
			filters = (conf[:use].rfm_force_array | filters.rfm_force_array).compact
			filters.each{|f| next unless conf[f]; conf.merge!(conf[f] || {})} if !filters.blank?
			conf.delete(:use)
			conf
		end
		
		    
    # This loads RFM_CONFIG into @config. It is not necessary,
    # as get_config will merge all configuration into RFM_CONFIG at runtime.
    #config RFM_CONFIG if defined? RFM_CONFIG

	end # module Config
	
end # module Rfm
