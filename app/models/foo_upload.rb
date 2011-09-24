class FooUpload
  include Mongoid::Document
  field :file_path, :type => String
  field :status, :type => String

  include Defaults
end
