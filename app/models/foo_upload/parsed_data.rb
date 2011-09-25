class FooUpload::ParsedData
  ROW_INDEX_COLUMN_NAME = :row_index

  include Mongoid::Document
  field ROW_INDEX_COLUMN_NAME, :type => Integer

  #TODO: would this be better with an embedded document array?
  #TEST: does this work across multiple FooUpload instances?
  #dynamically set the collection name on all interactions with this scope
  @@scoped_classes = {}
  def self.scoped_by_foo_upload(foo_upload)
    klass_collection_name = "foo_upload_parsed_data_for#{foo_upload.id}"
    fake_klass_suffix = "For#{foo_upload.id}"
    if !const_defined?(fake_klass_suffix)
      #new class extending our own
      klass = Class.new(self) do
        store_in klass_collection_name
      end
      const_set(fake_klass_suffix,klass)
    end
    const_get(fake_klass_suffix)
  end

  def self.destroy_collection
    collection.drop
  end

end