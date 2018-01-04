require 'logger'

# TODO: This should maybe to somewhere else
module Rfm
  @logger = Logger.new($stdout)
  def self.log
    @logger
  end
  
  # Dynamically load generic Refinements & Config under the above module.
  eval(File.read(File.join(File.dirname(__FILE__), '../refinements/refinements.rb')))
  eval(File.read(File.join(File.dirname(__FILE__), '../config/config.rb')))
end

require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'

