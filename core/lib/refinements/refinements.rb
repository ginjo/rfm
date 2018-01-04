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
  	
  	def filter(*keepers)
      select {|k,v| keepers.flatten.include?(k.to_s)}
    end
    
  	def filter!(*keepers)
      select! {|k,v| keepers.flatten.include?(k.to_s)}
    end
    
    # Used only in rfm Factory. Do not use otherwise.
    def rfm_filter(*args)
      options = args.rfm_extract_options!
      delete = options[:delete]
      self.dup.each_key do |k|
        self.delete(k) if (delete ? args.include?(k) : !args.include?(k))
      end
    end
  
    # Used in Connection
    # Convert hash to Rfm::CaseInsensitiveHash
    def to_cih
      new = Rfm::CaseInsensitiveHash.new
      self.each{|k,v| new[k] = v}
      new
    end
  end # refine Hash


  refine Object.singleton_class do
    # Adds methods to put instance variables in rfm_metaclass, plus getter/setters
    # This is useful to hide instance variables in objects that would otherwise show "too much" information.
    def meta_attr_accessor(*names)
      meta_attr_reader(*names)
      meta_attr_writer(*names)
    end
  
    def meta_attr_reader(*names)
      names.each do |n|
        define_method(n.to_s) {singleton_class.instance_variable_get("@#{n}")}
      end
    end
  
    def meta_attr_writer(*names)
      names.each do |n|
        define_method(n.to_s + "=") {|val| singleton_class.instance_variable_set("@#{n}", val)}
      end
    end
  end # refine Object.singleton_class


  refine Object do
    # TODO: Find a better way to do this without patching Object.
    #
    # Wrap an object in Array, if not already an Array,
    # since XmlMini doesn't know which will be returnd for any particular element.
    # See Rfm Layout & Record where this is used.
    def rfm_force_array
      return [] if self.nil?
      self.is_a?(Array) ? self : [self]
    end
  end # refine Object


  refine Array do
    # Taken from ActiveSupport extract_options!.
    def extract_options!
      last.is_a?(::Hash) ? pop : {}
    end
  end # refine Array


  refine Time do
    # NOT USED
    # Returns array of [date,time] in format suitable for FMP.
    def to_fm_components(reset_time_if_before_today=false)
      d = self.strftime('%m/%d/%Y')
      t = if (Date.parse(self.to_s) < Date.today) and reset_time_if_before_today==true
            "00:00:00"
          else
            self.strftime('%T')
          end
      [d,t]
    end
  end # refine Time


  refine String do
    # NOT USED
    def title_case
      self.gsub(/\w+/) do |word|
        word.capitalize
      end
    end
  end # refine String
  
end # Refinements
