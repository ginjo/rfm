# require all core files here.

# TODO: Probably move this to core_extensions.
module Rfm
  module Refinements
    refine Hash do
    	# Extract key-value pairs from self, given list of objects.
    	# Pulled from SplashRails project.
    	# If last object given is hash, it will be the collector for the extracted pairs.
    	# Extracted pairs are deleted from the original hash (self).
    	# Returns the extracted pairs as a hash or as the supplied collector hash.
    	# Attempts to ignore case.
    	def extract(*keys, **recipient)
    		#other_hash = args.last.is_a?(Hash) ? args.pop : {}
    		recipient = recipient.empty? ? Hash.new : recipient
    		recipient.tap do |other|
    			self.delete_if {|k,v| (keys.include?(k) || keys.include?(k.to_s) || keys.include?(k.to_s.downcase) || keys.include?(k.to_sym)) || keys.include?(k.to_s.downcase.to_sym) ? recipient[k]=v : nil}
    		end
    	end  
    end
  end
end


require 'rfm/core_extensions'
require 'rfm/config'
require 'rfm/error'
require 'rfm/compound_query'
require 'rfm/connection'
require 'rfm/sax_parser'

