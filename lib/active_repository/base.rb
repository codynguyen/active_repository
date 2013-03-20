require 'active_repository/associations'
require 'active_repository/uniqueness'
require 'active_repository/write_support'
require 'active_repository/sql_query_executor'
require 'active_repository/finders'
require 'active_repository/writers'
require 'active_repository/adapters/persistence_adapter'

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

module ActiveRepository

  # Base class for ActiveRepository gem.
  # Extends it in order to use it.
  # 
  # == Options
  #
  # There are 2 class attributes to help configure your ActiveRepository class:
  #
  #   * +class_model+: Use it to specify the class that is responsible for the
  #     persistence of the objects. Default is self, so it is always saving in
  #     memory by default.
  #
  #   * +save_in_memory+: Used to ignore the class_model attribute, you can use
  #     it in your test suite, this way all your tests will be saved in memory.
  #     Default is set to true so it saves in memory by default.
  #     
  #
  # == Examples
  #
  # Using ActiveHash to persist objects in memory:
  #
  #   class SaveInMemoryTest < ActiveRepository::Base
  #   end
  #
  # Using ActiveRecord/Mongoid to persist objects:
  #
  #    class SaveInORMOrODMTest < ActiveRepository::Base
  #      SaveInORMOrODMTest.set_model_class(ORMOrODMModelClass)
  #      SaveInORMOrODMTest.set_save_in_memory(false)
  #    end
  #
  # Author::    Caio Torres (mailto:efreesen@gmail.com)
  # License::   MIT
  class Base < ActiveHash::Base
    extend ActiveModel::Callbacks
    extend ActiveRepository::Finders
    extend ActiveRepository::Writers
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include ActiveRepository::Associations
    include ActiveRepository::Writers::InstanceMethods

    class_attribute :model_class, :save_in_memory, :instance_writer => false

    # attr_accessor :errors

    before_validation :set_timestamps

    self.save_in_memory = true if self.save_in_memory == nil

    # Returns all persisted objects
    def self.all
      (self == get_model_class ? super : PersistenceAdapter.all(self).map { |object| serialize!(object.attributes) })
      # self == get_model_class ? super : get_model_class.all.map { |object| serialize!(object.attributes) }
    end

    # Constantize class name
    def self.constantize
      self.to_s.constantize
    end

    # Deletes all persisted objects
    def self.delete_all
      self == get_model_class ? super : PersistenceAdapter.delete_all(self)
    end

    # Checks the existence of a persisted object with the specified id
    def self.exists?(id)
      self == get_model_class ? find_by_id(id).present? : PersistenceAdapter.exists?(self, id)
      # if self == get_model_class
      #   !find_by_id(id).nil?
      # else
      #   if mongoid?
      #     find_by_id(id).present?
      #   else
      #     get_model_class.exists?(id)
      #   end
      # end
    end

    # Returns the Class responsible for persisting the objects
    def self.get_model_class
      return self if self.model_class.nil? || self.save_in_memory?
      save_in_memory? ? self : self.model_class
    end

    # Converts Persisted object(s) to it's ActiveRepository counterpart
    def self.serialize!(other)
      case other.class.to_s
      when "Hash", "ActiveSupport::HashWithIndifferentAccess" then self.new.serialize!(other)
      when "Array"                                            then other.map { |o| serialize!(o.attributes) }
      when "Moped::BSON::Document"                            then self.new.serialize!(other)
      else self.new.serialize!(other.attributes)
      end
    end

    # Returns a array with the field names of the Class
    def self.serialized_attributes
      field_names.map &:to_s
    end

    # Sets the class attribute model_class, responsible to persist the ActiveRepository objects
    def self.set_model_class(value)
      self.model_class = value if model_class.nil?

      self.set_save_in_memory(self.model_class == self)

      field_names.each do |field_name|
        define_custom_find_by_field(field_name)
        define_custom_find_all_by_field(field_name)
      end
    end

    # Sets the class attribute save_in_memory, set it to true to ignore model_class attribute
    # and persist objects in memory
    def self.set_save_in_memory(value)
      self.save_in_memory = value
    end

    # Searches persisted objects that matches the criterias in the parameters.
    # Can be used in ActiveRecord/Mongoid way or in SQL like way.
    #
    # Example:
    #
    #   * RelatedClass.where(:name => "Peter")
    #   * RelatedClass.where("name = 'Peter'")
    def self.where(*args)
      raise ArgumentError.new("wrong number of arguments (0 for 1)") if args.empty?
      if self == get_model_class
        query = ActiveHash::SQLQueryExecutor.args_to_query(args)
        super(query)
      else
        objects = []
        args = args.first.is_a?(Hash) ? args.first : args

        PersistenceAdapter.where(self, args).each do |object|
          objects << self.serialize!(object.attributes)
        end

        objects
      end
    end

    # Persists the object using the class defined on the model_class attribute, if none defined it 
    # is saved in memory.
    def persist
      if self.valid?
        save_in_memory? ? save : self.convert.present?
      end
    end

    # Gathers the persisted object from database and updates self with it's attributes.
    def reload
      object = self.class.get_model_class.find(self.id)

      serialize! (self.class.get_model_class.find(self.id) || self).attributes
    end

    def save(force=false)
      if self.class == self.class.get_model_class
        object = self.class.get_model_class.find(self.id)

        if force || self.id.nil?
          self.id = nil if self.id.nil?
          super
        else
          object.save(true)
        end
        true
      else
        self.persist
      end
    end

    # Updates attributes from self with the attributes from the parameters
    def serialize!(attributes)
      unless attributes.nil?
        self.attributes = attributes
      end

      self.dup
    end

    protected
      # Find related object on the database and updates it with attributes in self, if it didn't
      # find it on database it creates a new one.
      def convert(attribute="id")
        klass = self.class.get_model_class
        object = klass.where(attribute.to_sym => self.send(attribute)).first

        object ||= self.class.get_model_class.new

        attributes = self.attributes

        attributes.delete(:id)

        object.attributes = attributes

        object.save

        self.id = object.id

        object
      end

      # Returns the value of the model_class attribute.
      def model_class
        self.model_class
      end

    private
      # Checks if model_class is a Mongoid model
      def self.mongoid?
        get_model_class.included_modules.include?(Mongoid::Document)
      end

      # Checks if model_class is a Mongoid model
      def mongoid?
        self.class.mongoid?
      end

      # Updates created_at and updated_at
      def set_timestamps
        self.created_at = DateTime.now.utc if self.respond_to?(:created_at=) && self.created_at.nil?
        self.updated_at = DateTime.now.utc if self.respond_to?(:updated_at=)
      end
  end
end
