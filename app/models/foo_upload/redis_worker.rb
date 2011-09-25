class FooUpload
  class RedisWorker
    attr_accessor :working_for

    def self.prepare_work_for(foo_upload,data)
      data.each do |datum|
        foo_upload.pending << datum.id
      end
      true
    rescue
      foo_upload.pending.clear
      raise
    end

    def initialize(foo_upload)
      self.working_for = foo_upload
    end

    def key_name(suffix)
      "#{self.working_for.class.name.underscore}:#{self.working_for.id}:#{suffix}"
    end
    def redis
      self.working_for.redis
    end

    def work_once
      # Atomic pop from pending queue to working queue # => [1,2,3,4], [a,b,c,d] # => [1,2,3], [4,a,b,c,d]
      id = redis.rpoplpush( key_name(:pending), key_name(:working) )

      # Add id => current time to working_times
      # NOT ATOMIC (we can't get the popped id from above until `multi` returns)
      # But, if a key is in the working queue, but lacking an entry in working_times,
      # we'll assume it failed and let the reaper process deal with it as a normal failure
      working_for.working_times[id] = Time.zone.now.to_i

      begin
        errors = []
        working_for.do_work_on(id,errors)

        # On successful complete, do atomically:
        #   remove self from working and working_times queues
        #   add self to successful set
        if errors.empty?
          redis.multi do
            working_for.working.delete(id)
            working_for.working_times.delete(id)
            working_for.successful << id
          end
          true
        # If unprocessible due to business rules:
        #   remove self from working and working_times queues
        #   add self to errored set
        #   set errored_messages[id] explaining why
        else
          redis.multi do
            working_for.working.delete(id)
            working_for.working_times.delete(id)
            working_for.errored << id
            working_for.errored_messages[id] = errors.to_json
          end
          false
        end
      rescue
        # If exceptions/crashes:
        #   let job fail, leaving entries in working and working times queues
        raise
      end
    end

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