require 'logger'

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
    #RFM-CORE
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
    formatter
    
    #SAXCHANGE
    backend
    default_class
    initial_object
    logger
    log_parser
    text_label
    tag_translation
    shared_variable_name
    template
    templates
    template_prefix
  ).compact.uniq
  
  Config.defaults = {
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
end

require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'
