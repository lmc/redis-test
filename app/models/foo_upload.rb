class FooUpload
  include Mongoid::Document
  field :file_path, type: String
  field :status, type: String

  after_destroy :destroy_parsed_data_collection

  include Defaults
  include RedisStructures


  def parsed_data
    FooUpload::ParsedData.scoped_by_foo_upload(self)
  end
  def parsed_data_collection_name
    "foo_upload_parsed_data_#{self.id}"
  end


  def parse_file
    header_mapping = nil
    row_index_name = FooUpload::ParsedData::ROW_INDEX_COLUMN_NAME
    row_index = 0
    CSV.foreach(self.file_path) do |row|
      if !header_mapping #first row of file
        header_mapping = row.map { |header| header.gsub(/\s+/,'_').downcase.to_sym } #'Email Address' -> :email_address
      else
        attributes = Hash[ header_mapping.zip(row) ] #[ [:email_address, 'test@example.com'] ] => { :email => 'test@example.com'}
        attributes[row_index_name] = row_index
        instance = self.parsed_data.new(attributes)
        instance.save!
        row_index += 1
      end
    end
  end

  def load_parsed_data_for_working
    FooUpload::RedisWorker.prepare_work_for(self,self.parsed_data.all)
  end


  protected

  def destroy_parsed_data_collection
    self.parsed_data.destroy_collection
  end
end
