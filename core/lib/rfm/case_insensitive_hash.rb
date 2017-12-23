module Rfm
  class CaseInsensitiveHash < Hash

    def []=(key, value)
      super(key.to_s.downcase, value)
    end

    def [](key)
      super(key.to_s.downcase)
    end

  end
end
