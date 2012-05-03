class Holiday
  include DataMapper::Resource
  property :id, Serial

  property :name, String, :length => 50, :nullable => false
  property :date, Date, :nullable => false, :unique => true
  property :shift_meeting, Integer, :nullable => true
  property :new_date, Date
  property :deleted_at, ParanoidDateTime

  has n, :holidays_fors

  def holiday_calendars
    holidays_fors.holiday_calendars
  end

  

end
