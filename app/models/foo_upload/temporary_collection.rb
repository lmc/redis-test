class FooUpload::TemporaryCollection
  include Mongoid::Document
  attr_accessor :collection_for

  def initialize(collection_for)
    self.collection_for = collection_for
  end

  def collection
    @collection ||= Mongoid::Collection.new(self.class,"foo_upload_temporary_collections_#{collection_for.id}")
  end
end