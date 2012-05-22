class Holiday
  include DataMapper::Resource
  property :id, Serial

  property :name, String, :length => 50, :required => true
  property :date, Date, :required => true, :unique => true
  property :shift_meeting, Integer, :required => false
  property :new_date, Date
  property :deleted_at, ParanoidDateTime

  has n, :holidays_fors

  def holiday_calendars
    holidays_fors.holiday_calendars
  end

  

end
