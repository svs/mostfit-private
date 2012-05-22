class Area
  include DataMapper::Resource

  property :id, Serial
  property :name, Text
  property :address,              Text,   :lazy => true
  property :contact_number,       String, :length => 40, :lazy => true
  property :landmark,             String, :length => 100, :lazy => true  
  property :creation_date,        Date,   :lazy => true, :default => Date.today

  has n, :branches
  belongs_to :region
  belongs_to :manager, :model => StaffMember

  validates_uniqueness_of :name, :scope => [:region]
  validates_presence_of :manager, :region
  validates_length_of :name, :min => 1

  def location
    Location.first(:parent_id => self.id, :parent_type => "area")
  end

end
