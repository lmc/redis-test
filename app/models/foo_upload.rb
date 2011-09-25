class FooUpload
  include Mongoid::Document
  field :file_path, type: String
  field :status, type: String

  after_destroy :destroy_parsed_data_collection

  include Defaults
  include RedisStructures

=begin
  FooUpload.destroy_all
  FooUpload.from_defaults.save!
  FooUpload.last.parse_file
  FooUpload.last.load_parsed_data_for_working
  FooUpload::RedisWorker.new(FooUpload.last).work_once
  [FooUpload::RedisWorker.new(FooUpload.last).work_once,FooUpload.last.work_complete?]

  FooUpload.last.parsed_data.all.map(&:id).map(&:to_s)
=end

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

  def do_work_on(id,errors)
    data = self.parsed_data.find(id)
    
    i = rand
    if i < 0.3
      puts "saved!"
    elsif i > 0.7
      puts "errored"
      errors << "Don't like this file"
    else
      puts "time to fail"
      raise "failed :("
    end
  end

  def work_complete?
    self.parsed_data.count == (successful.count + errored.count + failed.count)
  end


  protected

  def destroy_parsed_data_collection
    self.parsed_data.destroy_collection
  end
end
