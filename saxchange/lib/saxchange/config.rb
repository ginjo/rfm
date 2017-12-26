require 'forwardable'

module SaxChange
  module Config
    
    ###  CLASS LEVEL  ###
    
    # Top-level config goes in Config.@defaults
    singleton_class.send :attr_accessor, :defaults
    @defaults = {}

    # A one-off non-destructive merging of options with Config.@defaults.
    def self.config(**opts)
      @defaults.merge(opts)
    end
    
    # Allow classes prepended with Config to send '.config' method to the above Config.config.
    def self.prepended(other)
      other.singleton_class.extend Forwardable
      other.singleton_class.def_delegator :'SaxChange::Config', :config
    end
    
    
    ###  INSTANCE LEVEL  ###
    
    extend Forwardable
    
    # Delegate all calls to 'defaults' to the top-level.
    def_delegators :'SaxChange::Config', :defaults, :'defaults='
    
    # Allow writing to local config using 'config='
    attr_writer :config    
    
    # Read & write config to local instance, returning merge with top-level.
    # Read with config[] method.
    # Write with config(some:hash, goes:here).
    # Do not try to write with config[key]=, as it won't write to the @config var.
    def config(**opts)
      if opts.any?
        (@config ||= {}).merge!(opts)
      end
      (defaults || {}).merge(@config ||= {})
    end
    
    def initialize(opts={caller:self})
      #puts "#{self.class.name}#initialize, opts: #{opts}"
      @config ||= {}
      config(**opts)
      if method(__callee__).super_method.arity != 0
        super
      end
    end
    
  end # Config
end # SaxChange