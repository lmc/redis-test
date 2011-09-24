class FooUpload
  include Mongoid::Document
  field :file_path, type: String
  field :status, type: String

  include Defaults

  def parsed_data
    FooUpload::ParsedData.scoped_by_foo_upload(self)
  end
  def parsed_data_collection_name
    "foo_upload_parsed_data_#{self.id}"
  end

  
  # Atomic pop from pending queue to working queue # => [1,2,3,4], [a,b,c,d] # => [1,2,3], [4,a,b,c,d]
  #   Add id => current time to working_times
  # On successful complete, do atomically:
  #   remove self from working and working_times queues
  #   add self to successful set
  # If unprocessible due to business rules:
  #   remove self from working and working_times queues
  #   add self to errored set
  #   set errors[id] explaining why
  # If exceptions/crashes:
  #   let job fail, leaving entries in working and working times queues
  #   then...
  # Periodically, go through the working queue, take each id and check (working_times[id] + timeout_seconds) >= Time.now
  #   If so, check if failures[id] >= threshold, if so:
  #     remove self from working and working_times queues 
  #     add self to failed set
  #   Else
  #     increment failures[id]
  #     remove self from working and working_times queues 
  #     re-add self to pending queue

  # Queues can be safely and atomically read/written by multiple processes this way
  # Queues should be deleted at the end of the process, so save/serialize their data in another form if needed

  REDIS_KEYS = {
    pending:        "foo_upload:%s:pending",       #list, ids, atomic-popped into working list
    working:        "foo_upload:%s:working",       #list, ids
    working_times:  "foo_upload:%s:working_times", #hash, ids => starting times

    successful:     "foo_upload:%s:successful",    #set, ids
    errored:        "foo_upload:%s:errored",       #set, ids
    failed:         "foo_upload:%s:failed",        #set, ids

    errors:         "foo_upload:%s:errors"         #hash, ids => error info
    failure_counts: "foo_upload:%s:failure_counts" #hash, ids => number of failures
  }



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
end
