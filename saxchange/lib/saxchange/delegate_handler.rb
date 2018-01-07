module SaxChange
  # So far, the main purpose of this class is to automate inclusion/prepension of other modules
  # into the backend-specific saxchange handler class, when the class is defined.
  class DelegateHandler < SimpleDelegator
    def self.inherited(other)
      other.send :prepend, Handler
    end
  end
end