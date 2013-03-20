require 'active_repository/adapters/active_hash_adapter'
require 'active_repository/adapters/default_adapter'
require 'active_repository/adapters/mongoid_adapter'
require 'active_repository/adapters/mongo_mapper_adapter'

begin
  klass = Module.const_get(Mongoid::Document)
  unless klass.is_a?(Class)
    raise "Not defined"
  end
rescue
  module Mongoid
    module Document
    end
  end
end

begin
  klass = Module.const_get(DataMapper::Resource)
  unless klass.is_a?(Class)
    raise "Not defined"
  end
rescue
  module DataMapper
    module Resource
    end
  end
end

begin
  klass = Module.const_get(MongoMapper::Document)
  unless klass.is_a?(Class)
    raise "Not defined"
  end
rescue
  module MongoMapper
    module Document
    end
  end
end

class PersistenceAdapter
  class << self
    def get_adapter(klass)
      klass = klass.get_model_class
      if klass.included_modules.include?(Mongoid::Document)
        MongoidAdapter
      elsif klass.included_modules.include?(DataMapper::Resource)
        DataMapperAdapter
      elsif klass.included_modules.include?(MongoMapper::Document)
        adapter = MongoMapperAdapter
      else
        DefaultAdapter
      end
    end

    def all(klass)
      get_adapter(klass).all(klass)
    end

    def create(klass, attributes)
      get_adapter(klass).create(klass, attributes)
    end

    def delete_all(klass)
      get_adapter(klass).delete_all(klass)
    end

    def exists?(klass, id)
      get_adapter(klass).exists?(klass, id)
    end

    def find(klass, id)
      get_adapter(klass).find(klass, id)
    end

    def first(klass)
      get_adapter(klass).first(klass)
    end

    def last(klass)
      get_adapter(klass).last(klass)
    end

    def update_attribute(klass, id, key, value)
      get_adapter(klass).update_attribute(klass, id, key, value)
    end

    def update_attributes(klass, id, attributes)
      get_adapter(klass).update_attributes(klass, id, attributes)
    end

    def where(klass, args)
      get_adapter(klass).where(klass, args)
    end
  end

  def method_missing(sym, *args, &block)
    get_adapter(args.first).send(sym, args)
  end
end