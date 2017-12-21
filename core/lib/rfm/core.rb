# require all core files here.

require 'logger'

# TODO: This should maybe to somewhere else
module Rfm
  @logger = Logger.new($stdout)
  def self.log
    @logger
  end
end

require 'rfm/core_extensions'
require 'rfm/config'
require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'
require 'rfm/sax_parser'

