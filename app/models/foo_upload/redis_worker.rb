class FooUpload
  class RedisWorker
    attr_accessor :foo_upload_id

    def self.prepare_work_for(foo_upload,data)
      data.each do |datum|
        foo_upload.pending << datum.id
      end
      true
    rescue
      foo_upload.pending.clear
      raise
    end

    def initialize(foo_upload_id)
      self.foo_upload_id = foo_upload_id
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
    #   If so, check if failure_counts[id] >= threshold, if so:
    #     remove self from working and working_times queues 
    #     add self to failed set
    #   Else
    #     increment failures[id]
    #     remove self from working and working_times queues 
    #     re-add self to pending queue

    # Queues can be safely and atomically read/written by multiple processes this way
    # Queues should be deleted at the end of the process, so save/serialize their data in another form if needed

    # Should have a way to "reconcile" based off what Foo objects were actually created?

  end
end