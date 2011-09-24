class FooUpload
  include Mongoid::Document
  field :file_path, :type => String
  field :status, :type => String

  include Defaults

  def temporary_collection
    FooUpload::TemporaryCollection.new(self)
  end
end
