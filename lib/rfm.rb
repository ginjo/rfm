module Rfm
  PATH = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)

  #require 'thread' # some versions of ActiveSupport will raise error about Mutex unless 'thread' is loaded.
  
  # Do we need this?
  #require 'logger'
  
  require 'rfm-core'
  require 'rfm-model'
  require 'saxchange'

  autoload :VERSION,      'rfm/version'

  def info
    rslt = <<-EEOOFF
      Gem name: ginjo-rfm
      Version: #{VERSION}
      ActiveModel loadable? #{begin; Gem::Specification::find_all_by_name('activemodel')[0].version.to_s; rescue Exception; false; end}
      ActiveModel loaded? #{defined?(ActiveModel) ? 'true' : 'false'}
      XML default parser: #{SaxParser::Handler.get_backend}
      Ruby: #{RUBY_VERSION}
    EEOOFF
    rslt.gsub!(/^[ \t]*/, '')
    rslt
  rescue
    "Could not retrieve info: #{$!}"
  end

  def info_short
    "Using ginjo-rfm version #{::Rfm::VERSION} with #{SaxParser::Handler.get_backend}"
  end

  def logger
    @@logger ||= get_config[:logger] || Logger.new(STDOUT).tap {|l| l.formatter = proc {|severity, datetime, progname, msg| "#{datetime}: Rfm-#{severity} #{msg}\n"}}
  end

  alias_method :log, :logger

  def logger=(obj)
    @@logger = obj
  end

  # DEFAULT_CLASS = CaseInsensitiveHash
  # TEMPLATE_PREFIX = File.join(File.dirname(__FILE__), 'rfm/utilities/sax/')
  # TEMPLATES = {
  #   :fmpxmllayout => 'fmpxmllayout.yml',
  #   :fmresultset => 'fmresultset.yml',
  #   :fmpxmlresult => 'fmpxmlresult.yml',
  #   :none => nil
  # }

  extend self

end # Rfm
