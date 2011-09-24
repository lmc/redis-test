class FooUpload
  module RedisStructures
    def self.included(base)
      base.instance_eval do
        include Redis::Objects

        list     :pending          #ids, atomic-popped into working list
        list     :working          #ids
        hash_key :working_times    #ids => starting times

        set      :successful
        set      :errored
        set      :failed

        hash_key :errored_messages #ids => error info
        hash_key :failure_counts   #ids => number of failures
      end
    end
  end
end