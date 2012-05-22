class AuditTrail
  include DataMapper::Resource
  
  property :id,              Serial
  property :auditable_id,    Integer, :required => true, :index => true
  property :auditable_type,  String,  :required => true, :length => 50, :index => true
  property :message,         String
  property :action,          Enum[:create, :update, :delete],  :required => true, :index => true
  property :changes,         Yaml, :length => 20000
  property :created_at,      DateTime, :index => true
  property :type, Enum[:log, :warning, :error], :index => true
  belongs_to :user

  # Not sure what this means:
  # we need this dummy validation to define the reallocation context which bubbles down into AuditTrail as well. 
  validates_presence_of :created_at, :when => [:default, :reallocate]

  def trail_for(obj, limit = nil)
    attrs = {
      :auditable_type => obj.class.to_s,
      :auditable_id => obj.id,
      :order => [:created_at.desc] }
    attrs.merge!(:limit => limit) if limit
    self.all(attrs)
  end
end
