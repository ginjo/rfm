require 'logger'

# TODO: This can't go here.
# TODO: Create a top-level method for checking if a gem is registered in the current gemset.
if Gem::Specification.find{|g| g.name == 'saxchange'}
  autoload :SaxChange, 'saxchange'
end

# TODO: This should maybe to somewhere else
module Rfm
  @logger = Logger.new($stdout)
  def self.log
    @logger
  end
  
  # Dynamically load generic Refinements & Config under the above module.
  eval(File.read(File.join(File.dirname(__FILE__), '../ginjo_tools/refinements.rb')))
  eval(File.read(File.join(File.dirname(__FILE__), '../ginjo_tools/config.rb')))
  
  AllowableOptions = %w(
    account_name
    database
    database_url
    decimal_separator
    field_mapping
    file_name
    file_path
    formatter
    grammar
    host
    ignore_bad_data
    layout
    logger
    log_actions
    log_responses
    parser
    password
    path
    port
    proxy
    raise_on_401
    raise_invalid_option
    record_proc
    root_cert
    root_cert_name
    root_cert_path
    scheme
    ssl
    template
    timeout
    warn_on_redirect
  )
  
  AllowableOptions.push(*SaxChange::AllowableOptions) if Kernel.const_defined?(:SaxChange)
  
  AllowableOptions.delete_if(){|x| x[/^\s*\#/]}
  AllowableOptions.compact!
  AllowableOptions.uniq!
  
  Config.defaults = {
    :database_url => :DATABASE_URL,
    :host => 'localhost',
    :port => nil,
    :proxy=>false,  # array of (p_addr, p_port = nil, p_user = nil, p_pass = nil)
    :ssl => true,
    :root_cert => true,
    :root_cert_name => '',
    :root_cert_path => '/',
    :account_name => '',
    :password => '',
    :log_actions => false,
    :warn_on_redirect => true,
    :raise_on_401 => false,
    :timeout => 60,
    #:ignore_bad_data => false,
    #:template => nil,
    #:grammar => 'fmresultset',
    :raise_invalid_option => true
  }
  
  case 
    when Kernel.const_defined?(:SaxChange)
    
      # Add some options to SaxChange for parsing Rfm data.
      SaxChange::AllowableOptions.push *%w(
        grammar
        field_mapping
        decimal_separator
        layout
        connection
        record_proc
      )
      
      # As a side note, here's a way to pretty-print raw xml in ruby:
      # REXML::Document.new(xml_string).write($stdout, 2)
      
      # This can't go here, or it clobbers the template proc set by rfm-model.
      #SaxChange::Config.defaults[:template] = {'compact'=>true}
      Config.defaults[:parser] = SaxChange::Parser.new(Config.defaults)
      #puts "CORE setting formatter"
      Config.defaults[:formatter] = ->(io, options){options[:parser].parse(io, options)}
    else 
      Config.defaults[:formatter] = ->(io, options){ REXML::Document.new(io) }
  end
end # Rfm


require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'





