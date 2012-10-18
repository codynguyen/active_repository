require 'active_hash'



begin
  klass = Module.const_get(ActiveRecord::Rollback)
  unless klass.is_a?(Class)
    raise "Not defined"
  end
rescue
  module ActiveRecord
    class ActiveRecordError < StandardError
    end
    class Rollback < ActiveRecord::ActiveRecordError
    end
  end
end

module ActiveHash
  class Base
    def self.insert(record)
      if self.all.map(&:to_s).include?(record.to_s)
        record_index.delete(record.id.to_s)
        self.all.delete(record)
      end

      if record_index[record.id.to_s].nil? || !self.all.map(&:to_s).include?(record.to_s)
        @records ||= []
        record.attributes[:id] ||= next_id

        validate_unique_id(record) if dirty
        mark_dirty

        if record.valid?
          add_to_record_index({ record.id.to_s => @records.length })
          @records << record
        end
      end
    end

    def self.validate_unique_id(record)
      raise IdError.new("Duplicate Id found for record #{record.attributes}") if record_index.has_key?(record.id.to_s)
    end

    def readonly?
      false
    end

    def save(*args)
      record = self.class.find(self.id) if self.class.exists?(self.id)

      self.class.insert(self) unless record == self && record.to_s != self.to_s
      true
    end

    def persisted?
      other = self.class.find(id)
      self.class.all.map(&:id).include?(id) && created_at == other.created_at
    end

    def eql?(other)
      other.instance_of?(self.class) and not id.nil? and (id == other.id) and (created_at == other.created_at)
    end

    alias == eql?

    def self.exists?(id)
      begin
        find(id)
        true
      rescue RecordNotFound
        false
      end
    end
  end
end
