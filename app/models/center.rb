class Center
  include DataMapper::Resource
  include DateParser

  before :valid?, :convert_blank_to_nil
  before :valid?, :handle_meeting_days
  
  DAYS = [:none, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  property :id,                   Serial
  property :name,                 String, :length => 100, :nullable => false, :index => true
  property :code,                 String, :length => 12, :nullable => true, :index => true
  property :address,              Text,   :lazy => true
  property :contact_number,       String, :length => 40, :lazy => true
  property :landmark,             String, :length => 100, :lazy => true  
  property :meeting_day,          Enum.send('[]', *DAYS), :nullable => true, :default => :none, :index => true # DEPRECATED
  property :meeting_time_hours,   Integer, :length => 2, :index => true
  property :meeting_time_minutes, Integer, :length => 2, :index => true
  property :meeting_calendar,     Text # this is a comma separated list of dates and takes precedence over everything else.
  property :created_at,           DateTime, :nullable => false, :default => Time.now, :index => true
  property :creation_date,        Date
  belongs_to :branch
  belongs_to :manager, :child_key => [:manager_staff_id], :model => 'StaffMember'

  has n, :clients
  has n, :client_groups
  has n, :loan_history
  has n, :center_meeting_days
  has n, :weeksheets
  
  validates_is_unique   :code, :scope => :branch_id
  validates_length      :code, :min => 1, :max => 12

  validates_length      :name, :min => 3
  validates_is_unique   :name
  validates_present     :manager
  validates_present     :branch
  validates_with_method :meeting_time_hours,   :method => :hours_valid?
  validates_with_method :meeting_time_minutes, :method => :minutes_valid?
  validates_with_method :calendar_must_have_only_dates

  def self.search(q, per_page=10)
    if /^\d+$/.match(q)
      all(:conditions => ["id = ? or code=?", q, q], :limit => per_page)
    else
      all(:conditions => ["code=? or name like ?", q, q+'%'], :limit => per_page)
    end
  end

  def clear_cache
    @meeting_dates_array = nil
  end

  def self.meeting_days
    DAYS
  end

  # Public: Returns the meeting calendar as an array of dates
  # Returns nil if no calendar
  def calendar
    return nil if meeting_calendar.blank? or !calendar_must_have_only_dates
    c = self.meeting_calendar.split(/[\s,]/).reject(&:blank?).map{|d| Date.parse(d) rescue nil}.compact.select{|d| d >= from}.sort
  end

  def get_meeting_dates(to = SEP_DATE,from = creation_date)
    # DEPRECATED - Please use Center#meeting_dates. get_meeting_dates is non-idiomatic ruby
    meeting_dates(to, from)
  end


  # Public get a list of meeting dates between from and to if to is a Date. Else gets "to" meeting dates if to is an integer
  #
  # to -   optional. an Integer (number of meeting_dates) or a Date (meeting_dates before this date). Defaults to last loan_history date or SEP_DATE
  # from - optional. a Date representing the start date for this list. Defaults to first loan_history date or center creation date
  # a center must take the responsibility that center_meeting_days never overlap.
  #
  # Examples 
  #
  # meeting_dates
  # meeting_dates(10)
  # meeting_dates(Date.new(2012,12,21)
  # meeting_dates(Date.new(2012,12,21), Date.new(2012,01,01))
  #
  # Returns a list of center meeting dates 
  def meeting_dates(to = nil,from = nil)
    unless @meeting_dates_array
      # sigh - first time? ok, we'll build the array of meeting dates
      @meeting_dates_array = []
      
      # sometimes loans from another center might be moved to this center. they can be created before this centers creation date
      # therefore, we refer to the loan history table first and if there are no rows there, we refer to the creation date for the 'from' date if none is specified
      min_max_dates = LoanHistory.all(:center_id => self.id).aggregate(:date.min, :date.max)
      f = (min_max_dates[0] || self.creation_date)
      t = SEP_DATE
      
      # first check if we have an explicitly defined meeting calendar
      if ds = calendar
        ds = ds.select{|d| d <= t} if t.class == Date
        ds = ds[0..t - 1] if t.class == Fixnum
        @meeting_dates_array = ds
      else
        select = t.class == Date ? {:valid_from.lte => t} : {}
        dvs = center_meeting_days.all.select{|dv| dv.valid_from.nil? or dv.valid_from <= t}.map{|dv| [(dv.valid_from.nil? ? f : dv.valid_from), dv]}.to_hash
        # then cycle through this hash and get the appropriate dates
        dates = []
        dvs.keys.sort.each_with_index{|date,i|
          d1 = [date,f].max
          d1 -= 1 if [dvs[date].what].flatten.include?(d1.weekday)
          d2 = dvs.keys.sort[i+1] || (t.class == Date ? t : (t - dates.count - 1))
          _ds = dvs[date].get_dates(d1,d2)
          _ds = _ds[0..(t - dates.count - 1)] if t.class == Fixnum
          dates.concat(_ds)
        }
        @meeting_dates_array = dates.sort
      end
    end
    if to.class == Date
      if from
        return @meeting_dates_array.select{|d| d >= from and d <= to}
      else
        return @meeting_dates_array.select{|d| d <= to}
      end
    elsif !to.nil?
      if from
        return @meeting_dates_array.select{|d| d >= from}[0..to-1]
      else
        return @meeting_dates_array[0..to-1]
      end
    else
      if from 
        return @meeting_dates_array.select{|d| d >= from}
      else
        return @meeting_dates_array
      end
    end
  end
  
  # we need a slice method to respond to Loan#installment_source
  def slice(from, to)
    meeting_dates(to, from)
  end
  
  # Public: returns the date vector in use for a given date.
  #
  # DEPRECATED use meeting_day_for(date).date_vector
  def date_vector_for(date)
    first_cmd_date = center_meeting_days.aggregate(:valid_from.min) || Date.new(2100,12,31)
    if date < first_cmd_date
      DateVector.new(1, meeting_day, 1, :week, creation_date, first_cmd_date)
    eles
      (center_meeting_days.all(:order => [:valid_from]).select{|cmd| cmd.valid_from <= date and cmd.valid_upto >= date}[0]).date_vector
    end
  end

    
  # Public: returns the meeting day for a given date
  #
  # date: the Date for which the meeting day is desired
  #
  # Returns an element of WEEKDAY
  def meeting_day_for(date)
    meeting_dates(date)[-1].weekday
  end
  
  # Public: returns the CenterMeetingDay object for a given date
  #
  # date: the Date for which the meeting day is desired
  #
  # Returns a CenterMeetingDay
  def center_meeting_day_for(date)
    @cmd_hash ||= center_meeting_days.sort_by{|cmd| cmd.valid_from || Date.new(1900,1,1)}
    @cmd_hash.select{|cmd| (cmd.valid_from || Date.new(1900,1,1)) <= date}[-1]
  end

  
  # Public: Get the next meeting date for a center given a date
  #
  # date : the Date after which to get the next meeting date
  #
  # Returns a Date
  def next_meeting_date_from(date)    
    # first refer to the LoanHistory. Sometimes, some funky loans might be in here and we don't want to depend on center meeting dates in
    # the first instance
    # r_date = (LoanHistory.first(:center_id => self.id, :date.gt => date, :order => [:date], :limit => 1) or Nothing).date
    # return r_date if r_date
    #oops...no loans in this center. use center_meeting_dates
    # get 2 meeting dates because if the date parameter is a meeting date, it gets included in the meeting_dates result.
    self.meeting_dates(nil, date + 1)[0]
  end
  
  # Public: Get the previous meeting date for a center given a date
  #
  # date : the Date for which to get the previous meeting date
  #
  # Returns a Date
  def previous_meeting_date_from(date)
    #likewise for this (see comment above)
    # r_date = (LoanHistory.first(:center_id => self.id, :date.lte => date, :order => [:date.desc], :limit => 1) or Nothing).date
    # return r_date if r_date
    #oops...no loans in this center. use center_meeting_dates
    self.meeting_dates(date - 1,nil)[-1]
  end

  # Public: is this date a meeting date?
  #
  # date: the Date for which to check
  #
  # Returns a Boolean
  def meeting_day?(date)
    self.meeting_dates(date, date).include?(date)
  end

  # Public: returns a list of centers that meet on a particular weekday, filtered by a selection
  #
  # day: a Symbol representing a weekday
  # selection: a Hash containing a selection query for DM
  # as_of: a Date as of which to make the selection
  # Examples
  #
  # Center.meeting_on(:wednesday)
  # Center.meeting_on(:monday, :branch => Branch.first)
  def self.meeting_on(day, selection = {}, as_of = Date.today)
    raise ArgumentError.new("no such weekday: #{day}") unless WEEKDAYS.include(day)
    Center.all(selection).center_meeting_days.all(:valid_from.lte => as_of, :valid_from.gte => as_of, :what => day).centers
  end

  def meeting_time
    meeting_time_hours.two_digits + ':' + meeting_time_minutes.two_digits rescue "00:00"
  end

  def self.paying_today(user, date = Date.today, branch_id = nil)
    # returns a list of centers paying today
    selection = {:date => date}.merge(branch_id ? {:branch_id => branch_id} : {})
    center_ids = LoanHistory.all(selection).aggregate(:center_id)
    centers = center_ids.blank? ? [] : Center.all(:id => center_ids)
    if user.staff_member
      staff = user.staff_member
      centers = (staff.branches.count > 0 ? ([staff.centers, staff.branches.centers].flatten.uniq & centers) : (staff.centers & centers))
    end
    centers
  end
  
  def loans(hash={})
    self.clients.loans.all(hash)
  end
  
  def leader
    CenterLeader.first(:center => self, :current => true)
  end
  
  def leader=(cid)
    Client.get(cid).make_center_leader rescue false
  end

  def location
    Location.first(:parent_id => self.id, :parent_type => "center")
  end
  
  def self.meeting_today(date=Date.today, user=nil)
    # this makes no sense
    user = User.first
    center_ids = LoanHistory.all(:date => date).aggregate(:center_id)
    # restrict branch manager and center managers to their own branches
    if user.role==:staff_member
      st = user.staff_member
      center_ids = ([st.branches.centers.map{|x| x.id}, st.centers.map{|x| x.id}].flatten.compact) & center_ids
    end
    Center.all(:id => center_ids)
  end

  # Public: gives the minimum loan history date or the center creation date
  def min_date
    LoanHistory.all(:center_id => self.id).aggregate(:date.min) || self.creation_date
  end
  

  private

  def hours_valid?
    return true if (0..23).include? meeting_time_hours.to_i
    [false, "Hours of the meeting time should be within 0-23"]
  end
  def minutes_valid?
    return true if (0..59).include? meeting_time_minutes.to_i
    [false, "Minutes of the meeting time should be within 0-59"]
  end
  def manager_is_an_active_staff_member?
    return true if manager and manager.active
    [false, "Cannot set #{self.manager.name} as center manager because this staff member is not currently not active"]
  end
  

 
  def handle_meeting_days
    # this function creates the first center meeting day for the center when only a meeting day is specified.
    # we will soon deprecate the meeting_day field and work only with center_meeting_days
    if center_meeting_days.blank? or (center_meeting_days.first.valid_from and center_meeting_days.first.valid_from > self.min_date)
      unless meeting_day == :none
        cmd = CenterMeetingDay.new(:valid_from => nil, :valid_upto => nil, :center_id => self.id, :meeting_day => (meeting_day || :none))
        self.center_meeting_days << cmd
      end
    end

  end

  def convert_blank_to_nil
    self.attributes.each{|k, v|
      if v.is_a?(String) and v.empty? and self.class.properties.find{|x| x.name == k}.type==Integer
        self.send("#{k}=", nil)
      end
    }
  end

  def calendar_must_have_only_dates
    return true if meeting_calendar.nil?
    (!(meeting_calendar.split(/[\s,]/).reject(&:blank?).map{|d| Date.parse(d) rescue nil}.include?(nil))) rescue false
  end

end
