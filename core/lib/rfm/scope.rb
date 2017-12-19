require 'rfm'
require 'rfm/base'

module Rfm
  module Scope

    SCOPE = Proc.new {[]}

    # Add scoping to Rfm::Base class methods for querying fmp records.
    # Usage:
    #   class MyModel < Rfm::Base
    #     SCOPE = proc { |optional-scope-args| <single-or-array-of-fmp-request-hashes> }
    #   end
    #
    # Optionally pass :scope=>fmp-request-hash-or-array or :scope_args=>anything
    # in the FMP request options hash, to be used at scoping time,
    # instead of above scope constant.

    def find(*args)
      new_args = apply_scope(args)
      super(*new_args)
    end

    def count(*args)
      new_args = apply_scope(args)
      super(*new_args)
    end
    
    def delineate_query(*request)
      options = (request.last.is_a?(Hash) && request.size > 1) ? request.pop : {}
      query = request.pop || {}
      action = request.pop || (query.size==0 ? :all : :find)
      #puts "DELINEATE_QUERY action:#{action} query:#{query} options:#{options}"
      [action, query, options]
    end

    # Mix scope requests with user requests with a constraining AND logic.
    # Also handles request options.
    def apply_scope(target_request, raw_scope=nil)
      # Separate target_request into query, opts, with query always enclosed in array.
      target_query, target_opts = delineate_query(*target_request)[1..2].inject{|q,o| [[q].flatten, o]}
      # Retrieve :scope_args, if any, from target_request.
      scope_args = target_opts.delete(:scope_args) || self
      # Get raw scope from several possible sources
      raw_scope = raw_scope || target_opts.delete(:scope) || self::SCOPE
      # Compile raw scope from Proc, if necessary, into full scope_request
      scope_request = [raw_scope.is_a?(Proc) ? raw_scope.call(scope_args) : raw_scope].flatten(1).compact
      # Separate scope_request into query, opts, with query always enclosed in array.
      scope_query, scope_opts = delineate_query(*scope_request)[1..2].inject{|q,o| [[q].flatten, o]}
      # Extract scope & target omits into discrete arrays.
      scope_omits, target_omits = [],[]
      target_query.delete_if{|q| target_omits.push(q) if q[:omit]}
      scope_query.delete_if{|q| scope_omits.push(q) if q[:omit]}
      
      #puts "APPLY_SCOPE TARGET query:#{target_query} omits:#{target_omits} opts:#{target_opts}"
      #puts "APPLY_SCOPE SCOPE query:#{scope_query} omits:#{scope_omits} opts:#{scope_opts}"

      # Return original request if no scoping can be done.
      return target_request unless (target_query.is_a?(Array) || target_query.is_a?(Hash)) && (scope_query.size > 0 || scope_omits.size > 0 || scope_opts.size > 0)
      
      # Create product of target & scope
      scoped_queries = case
        when (target_query.any? && !scope_query.any?); target_query
        when (scope_query.any? && !target_query.any?); scope_query
        #else target_query.product(scope_query).map{|a,b| (b[:omit] || a[:omit]) ? nil : a.merge(b)}.compact
        else target_query.product(scope_query).map{|a,b| a.merge(b)}
      end
      scoped_omits = (target_omits | scope_omits)
      
      #puts "APPLY_SCOPE OUTPUT #{[scoped_queries | scoped_omits, target_opts.merge(scope_opts)]}"
      
      [scoped_queries | scoped_omits, target_opts.merge(scope_opts)]
    end

    # def self.extended(base)
    #   puts "Extending #{base} with Scope"
    # end

  end # Scope


  class Base
    SCOPE = Scope::SCOPE

    class << self
      # When Rfm::Base is inherited, the inheritor will extend this Scope module
      alias_method :inherited_orig, :inherited
      def inherited(model)
        super(model)
        model.send :extend, Scope
      end
    end
  end

end # Rfm
