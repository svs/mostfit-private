class Occupation
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :code, String, :length => 3

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :code

  has n, :clients
  has n, :loans
  default_scope(:default).update(:order => [:name])
end
