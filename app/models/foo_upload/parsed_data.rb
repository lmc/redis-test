class FooUpload::ParsedData
  ROW_INDEX_COLUMN_NAME = :row_index

  include Mongoid::Document
  field ROW_INDEX_COLUMN_NAME, :type => Integer

  #dynamically set the collection name on all interactions with this scope
  def self.scoped_by_foo_upload(foo_upload)
    scoped_collection_name = "foo_upload_parsed_data_#{foo_upload.id}"
    scoped_collection_method = lambda do
      @collection ||= Mongoid::Collection.new(self,scoped_collection_name)
    end
    scoped_class = self
    (class << scoped_class; self; end).instance_eval do
      define_method(:collection,&scoped_collection_method)
    end
    scoped_class
  end

end