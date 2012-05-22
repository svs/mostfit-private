class Attendance
  include DataMapper::Resource
  
  ATTENDANCY_STATES = ["present", "late", "on leave", "absent", "proxy"]

  property :id,              Serial
  property :date,            Date, :index => true
  property :status,          Enum.send('[]', *ATTENDANCY_STATES), :required => true, :index => true
  property :desktop_id,          Integer
  property :origin,              String, :default => DEFAULT_ORIGIN

  belongs_to :client
  belongs_to :center

  validates_presence_of     :status
  validates_presence_of     :client,:date
  validates_with_method :date, :method=>:not_in_future? 

  def self.attendancy_states
    ATTENDANCY_STATES
  end

  def not_in_future?
    return true if date and (date<=Date.today)
    [false, "Date should not be in future"]
  end
end
