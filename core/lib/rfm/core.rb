# require all core files here.

require 'logger'
#require 'saxchange'

# TODO: This should maybe to somewhere else
module Rfm
  @logger = Logger.new($stdout)
  def self.log
    @logger
  end
end

# PARSER_DEFAULTS = {
#   :default_class => Hash,  #CaseInsensitiveHash,
#   :template_prefix => File.join(File.dirname(__FILE__), 'sax_templates/'),
#   :templates => {
#     :fmpxmllayout => 'fmpxmllayout.yml',
#     :fmresultset => 'fmresultset.yml',
#     :fmpxmlresult => 'fmpxmlresult.yml',
#     :none => nil
#   }
# }

require 'rfm/core_extensions'
require 'rfm/config'
require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'
#require 'rfm/parsers/sax'

