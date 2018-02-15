module Rfm
  # Add load path for library usage without rubygems.
  CORE_PATH = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(CORE_PATH) unless $LOAD_PATH.include?(CORE_PATH)
end

require 'rfm/core'