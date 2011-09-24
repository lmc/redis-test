require 'tempfile'
require 'csv'
require 'faker'

class FooUpload
  module Defaults
    TMP_PATH = Rails.root.join('tmp')
    def self.included(base)
      base.send(:extend,ClassMethods)
    end

    module ClassMethods
      def from_defaults
        csv_data = CSV.generate("") do |csv| 
          csv << ["First Name","Last Name","Email Address"]
          10.times do |index|
            csv << [Faker::Name.first_name,Faker::Name.last_name,Faker::Internet.email]
          end
        end
        file = Tempfile.new(['foo_upload-','.csv'],TMP_PATH)
        file.write(csv_data)
        file.close

        new(:file_path => file.path)
      end
    end
  end
end