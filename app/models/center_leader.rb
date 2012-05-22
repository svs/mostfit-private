class CenterLeader
  include DataMapper::Resource
  
  property :id, Serial
  property :client_id, Integer, :required => true, :index => true
  property :center_id, Integer, :required => true, :index => true
  property :date_assigned, Date, :required => true, :index => true
  property :date_deassigned, Date, :required => false, :index => true
  property :current, Boolean, :required => false, :index => true, :default => true
  
  belongs_to :center
  belongs_to :client
end
