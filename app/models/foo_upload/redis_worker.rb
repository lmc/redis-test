class FooUpload
  class RedisWorker
    attr_accessor :working_for
    WORKER_TIMEOUT = 3
    REAPER_TIMEOUT_CHECK = WORKER_TIMEOUT + 2
    REAPER_FAILURE_LIMIT = 3

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
      Timeout.timeout(WORKER_TIMEOUT) do
        id = reserve_once
        log "reserved #{id}"

        if id.nil?
          log "queue empty"
          return nil
        end

        begin
          log "starting work on #{id}"
          errors = []
          working_for.do_work_on(id,errors)

          if errors.empty?
            log "success"
            success!(id)
          else
            log "errored: #{errors.inspect}"
            errored!(id,errors)
          end
        rescue
          log "failed"
          # If exceptions/crashes:
          #   let job fail, leaving entries in working and working times queues
          raise
        end
      end
    end

    def reserve_once
      # Atomic pop from pending queue to working queue # => [1,2,3,4], [a,b,c,d] # => [1,2,3], [4,a,b,c,d]
      id = redis.rpoplpush( key_name(:pending), key_name(:working) )

      # Add id => current time to working_times
      # NOT ATOMIC (we can't get the popped id from above until `multi` returns)
      # But, if a key is in the working queue, but lacking an entry in working_times,
      # we'll assume it failed and let the reaper process deal with it as a normal failure
      working_for.working_times[id] = Time.zone.now.to_i if id #if nil queue is empty, so need to mark a start time

      id
    end

    # Periodically, go through the working queue, take each id and check (working_times[id] + timeout_seconds) >= Time.now
    #   If so, check if failure_counts[id] >= threshold, if so:
    #     remove self from working and working_times queues 
    #     add self to failed set
    #   Else
    #     increment failures[id]
    #     remove self from working and working_times queues 
    #     re-add self to pending queue
    def reaper
      #race condition in that we could look up a job, find that it's timed out and requeue it,
      #BUT THEN while we're doing that, the job actually completes successfully
      #so we enforce a time limit on workers with WORKER_TIMEOUT
      #and only jobs with REAPER_TIMEOUT_CHECK (which is a second or two longer) are considered timed out
      working_for.working_times.all.each_pair do |id,timestamp|
        log "checking #{id},#{timestamp}"
        log "  #{(timestamp.to_i + REAPER_TIMEOUT_CHECK)}"
        log "  #{Time.zone.now.to_i} >= #{(timestamp.to_i + REAPER_TIMEOUT_CHECK)}"
        if Time.zone.now.to_i >= (timestamp.to_i + REAPER_TIMEOUT_CHECK)
          log "seems to have timed out"
          failures = working_for.failure_counts.incrby(id)
          log "failure count: #{failures}"
          log "  #{failures} >= #{REAPER_FAILURE_LIMIT}"
          if failures >= REAPER_FAILURE_LIMIT
            log "too many failures, removing from work"
            redis.multi do
              remove_from_working(id)
              working_for.failed << id
            end
          else
            log "inserting back into pending"
            redis.multi do
              remove_from_working(id)
              working_for.pending << id
            end
          end
        end
      end
    end

    # Queues can be safely and atomically read/written by multiple processes this way
    # Queues should be deleted at the end of the process, so save/serialize their data in another form if needed

    # Should have a way to "reconcile" based off what Foo objects were actually created?


    protected

    def log(*args)
      #puts *args
    end

    # On successful complete, do atomically:
    #   remove self from working and working_times queues
    #   add self to successful set
    def success!(id)
      redis.multi do
        remove_from_working(id)
        working_for.successful << id
      end
      true
    end

    # If unprocessible due to business rules:
    #   remove self from working and working_times queues
    #   add self to errored set
    #   set errored_messages[id] explaining why
    def errored!(id,errors)
      redis.multi do
        remove_from_working(id)
        working_for.errored << id
        working_for.errored_messages[id] = errors.to_json
      end
      false
    end

    def remove_from_working(id)
      working_for.working.delete(id)
      working_for.working_times.delete(id)
    end
  end
end