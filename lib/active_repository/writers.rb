module ActiveRepository
  module Writers
    def create(attributes={})
      object = get_model_class.new(attributes)

      object.id = nil if exists?(object.id)

      if get_model_class == self
        object.save
      else
        repository = serialize!(object.attributes)
        repository.valid? ? (object = get_model_class.create(attributes)) : false
      end

      serialize!(object.attributes) unless object.class.name == self
    end

    def find_or_create(attributes)
      object = get_model_class.where(attributes).first

      object = model_class.create(attributes) if object.nil?

      serialize!(object.attributes)
    end

    def create(attributes={})
      object = get_model_class.new(attributes)

      object.id = nil if exists?(object.id)

      if get_model_class == self
        object.save
      else
        repository = serialize!(object.attributes)
        repository.valid? ? (object = get_model_class.create(attributes)) : false
      end

      serialize!(object.attributes) unless object.class.name == self
    end


    module InstanceMethods
      def attributes=(new_attributes)
        new_attributes.each do |k,v|
          self.send("#{k.to_s == '_id' ? 'id' : k.to_s}=", v)
        end
      end

      def update_attribute(key, value)
        if self.class == self.class.get_model_class
          super(key,value)
        else
          object = self.class.get_model_class.find(self.id)

          if mongoid?
            super(key,value)
            key = key.to_s == 'id' ? '_id' : key.to_s
          end

          object.update_attribute(key, value)
          object.save
        end

        self.reload
      end

      def update_attributes(attributes)
        object = nil
        if mongoid?
          object = self.class.get_model_class.find(self.id)
        else
          object = self.class.get_model_class.find(self.id)
        end

        attributes.each do |k,v|
          object.update_attribute("#{k.to_s}", v) unless k == :id
        end

        self.reload
      end
    end
  end
end