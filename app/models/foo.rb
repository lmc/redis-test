class Foo
  include Mongoid::Document
  field :first_name, type: String
  field :last_name, type: String
  field :email_address, type: String

  validate :first_name_is_valid


  protected

  def first_name_is_valid
    errors.add(:first_name,"starts with a letter I don't like") if first_name[0] =~ /[a-g]/i
  end
end