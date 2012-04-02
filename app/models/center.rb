class Center
  include DataMapper::Resource
  include DateParser

  attr_accessor :meeting_day_change_date

  before :save, :convert_blank_to_nil
  after  :save, :handle_meeting_date_change
  before :save, :set_meeting_change_date
  before :create, :set_meeting_change_date
  before :valid?, :convert_blank_to_nil

  
  DAYS = [:none, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  property :id,                   Serial
  property :name,                 String, :length => 100, :nullable => false, :index => true
  property :code,                 String, :length => 12, :nullable => true, :index => true
  property :address,              Text,   :lazy => true
  property :contact_number,       String, :length => 40, :lazy => true
  property :landmark,             String, :length => 100, :lazy => true  
  property :meeting_day,          Enum.send('[]', *DAYS), :nullable => false, :default => :none, :index => true
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

  # validates_with_method :creation_date_ok

  def self.from_csv(row, headers)
    hour, minute = row[headers[:center_meeting_time_in_24h_format]].split(":")
    branch       = Branch.first(:name => row[headers[:branch]].strip)
    staff_member = StaffMember.first(:name => row[headers[:manager]])

    creation_date = ((headers[:creation_date] and row[headers[:creation_date]]) ? row[headers[:creation_date]] : Date.today)
    obj = new(:name => row[headers[:center_name]], :meeting_day => row[headers[:meeting_day]].downcase.to_s.to_sym, :code => row[headers[:code]],
              :meeting_time_hours => hour, :meeting_time_minutes => minute, :branch_id => branch.id, :manager_staff_id => staff_member.id,
              :creation_date => creation_date, :upload_id => row[headers[:upload_id]])
    [obj.save, obj]
  end

  def self.search(q, per_page=10)
    if /^\d+$/.match(q)
      all(:conditions => ["id = ? or code=?", q, q], :limit => per_page)
    else
      all(:conditions => ["code=? or name like ?", q, q+'%'], :limit => per_page)
    end
  end

  def self.meeting_days
    DAYS
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
    # sometimes loans from another center might be moved to this center. they can be created before this centers creation date
    # therefore, we refer to the loan history table first and if there are no rows there, we refer to the creation date for the 'from' date if none is specified
    min_max_dates = LoanHistory.all(:center_id => self.id).aggregate(:date.min, :date.max)
    from ||= (min_max_dates[0] || self.creation_date)
    to   ||= (min_max_dates[1] || SEP_DATE)
    # first refer to the meeting_calendar
    unless self.meeting_calendar.blank?
      ds = self.meeting_calendar.split(/[\s,]/).reject(&:blank?).map{|d| Date.parse(d) rescue nil}.compact.select{|d| d >= from}.sort
      if to
        ds = ds.select{|d| d <= to} if to.is_a? Date
        ds = ds[0..to - 1] if to.is_a? Numeric
      end
      return ds
    end
    # then check the date vectors.
    select = to.class == Date ? {:valid_from.lte => to} : {}
    dvs = center_meeting_days.all.select{|dv| dv.valid_from.nil? or dv.valid_from <= to}.map{|dv| [(dv.valid_from.nil? ? from : dv.valid_from), dv]}.to_hash
    
    # then cycle through this hash and get the appropriate dates
    dates = []
    dvs.keys.sort.each_with_index{|date,i|
      d1 = [date,from].max
      d1 -= 1 if [dvs[date].what].flatten.include?(d1.weekday)
      d2 = dvs.keys.sort[i+1] || (to.class == Date ? to : (to - dates.count - 1))
      _ds = dvs[date].get_dates(d1,d2)
      _ds = _ds[0..(to - dates.count - 1)] if to.class == Fixnum
      dates.concat(_ds)
    }
    dates.sort
  end

  # Public: returns the date vector in use for a given date.
  #
  # DEPRECATED use meeting_day_for(date).date_vector
  def date_vector_for(date)
    first_cmd_date = center_meeting_days.aggregate(:valid_from.min) || Date.new(2100,12,31)
    if date < first_cmd_date
      DateVector.new(1, meeting_day, 1, :week, creation_date, first_cmd_date)
    else
      (center_meeting_days.all(:order => [:valid_from]).select{|cmd| cmd.valid_from <= date and cmd.valid_upto >= date}[0]).date_vector
    end
  end

    
  # a simple catalog (Hash) of center names and ids grouped by branches
  # returns some like: {"One branch" => {1 => 'center1', 2 => 'center2'}, "b2" => {3 => 'c3', 4 => 'c4'}} 
  #
  # DEPRECATED this should probably move to center_helpers or something as it is only used on the view side
  def self.catalog(user=nil)
    result = {}
    branch_names = {}

    if user.staff_member
      staff_member = user.staff_member
      [staff_member.centers.branches, staff_member.branches].flatten.each{|b| branch_names[b.id] = b.name }
      centers = [staff_member.centers, staff_member.branches.centers].flatten
    else
      Branch.all(:fields => [:id, :name]).each{|b| branch_names[b.id] = b.name}
      centers = Center.all(:fields => [:id, :name, :branch_id])
    end
         
    centers.each do |center|
      branch = branch_names[center.branch_id]
      result[branch] ||= {}
      result[branch][center.id] = center.name
    end
    result
  end

  # Public: returns the meeting day for a given date
  #
  # date: the Date for which the meeting day is desired
  #
  # Returns a CenterMeetingDay
  def meeting_day_for(date)
    CenterMeetingDay.in_force_on(date, :id => self.id)[0]
  end
  
  
  # Public: Get the next meeting date for a center given a date
  #
  # date : the Date after which to get the next meeting date
  #
  # Returns a Date
  def next_meeting_date_from(date)    
    r_date = (LoanHistory.first(:center_id => self.id, :date.gt => date, :order => [:date], :limit => 1) or Nothing).date
    return r_date if r_date
    #oops...no loans in this center. use center_meeting_dates
    # get 2 meeting dates because if the date parameter is a meeting date, it gets included in the meeting_dates result.
    self.meeting_dates(2, date).reject{|d| d == date}.sort[0] 
  end
  
  # Public: Get the previous meeting date for a center given a date
  #
  # date : the Date for which to get the previous meeting date
  #
  # Returns a Date
  def previous_meeting_date_from(date)
    r_date = (LoanHistory.first(:center_id => self.id, :date.lte => date, :order => [:date.desc], :limit => 1) or Nothing).date
    return r_date if r_date
    #oops...no loans in this center. use center_meeting_dates
    self.meeting_dates(date).reject{|d| d == date}.sort[-1]
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
    [false, "Receiving staff member is currently not active"]
  end
  
  def creation_date_ok
    return true if clients.map{|c| c.loans}.count == 0
    return true if creation_date <= loans.aggregate(:applied_on.min)
    return [false, "Creation date cannot be after the first loan application date"]
  end

  def handle_meeting_date_change
    # no need to do all this if meeting date was not changed
    return true unless self.meeting_day_change_date

    date = self.meeting_day_change_date

    if not CenterMeetingDay.first(:center => self)
      # FIXME: This line appears to be failing, because the period attribute is left blank and should be one of %w[week month] probably true in the "elsif" below as well. This means new centers never get a meeting day.
      CenterMeetingDay.create(:center_id => self.id, :valid_from => creation_date||date, :meeting_day => self.meeting_day)
    elsif self.meeting_day != self.meeting_day_for(date)
      if prev_cm = CenterMeetingDay.first(:center_id => self.id, :valid_from.lte => date, :order => [:valid_from.desc])
        # previous CMD should be valid upto date - 1
        prev_cm
        prev_cm.valid_upto = date - 1        
        prev_cm
        prev_cm.save!
      end
      
      # next CMD's valid from date should be valid upto limit for this CMD
      if next_cm = CenterMeetingDay.first(:center => self, :valid_from.gt => date, :order => [:valid_from])
        valid_upto = next_cm.valid_from - 1
      else
        valid_upto = Date.new(2100, 12, 31)
      end
      CenterMeetingDay.create!(:center_id => self.id, :valid_from => date, :meeting_day => self.meeting_day, :valid_upto => valid_upto)
    end
    #clear cache
    @meeting_days = nil 
    Center.get(self.id).clients(:fields => [:id, :center_id]).loans.each{|l|
      if [:outstanding, :disbursed].include?(l.status)
        l.update_history
      end
    }
    return true
  end  

  def handle_meeting_days
    # this function creates the first center meeting day for the center when only a meeting day is specified.
    # we will soon deprecate the meeting_day field and work only with center_meeting_days
    if center_meeting_days.blank? or center.meeting_days.first.valid_from > self.min_date
      unless meeting_day == :none
        cmd = CenterMeetingDay.new(:valid_from => nil, :valid_upto => nil, :center_id => self.id, :meeting_day => (meeting_day || :none))
        self.center_meeting_days << cmd
      end
    end
  end

  def get_meeting_date(date, direction)
    number = 1
    if direction == :next
      nwday = (date + number).wday
      while (meet_day = Center.meeting_days.index(meeting_day_for(date + number)) and meet_day > 0 and nwday != meet_day)
        number += 1
        nwday = (date + number).wday
        nwday = 7 if nwday == 0
      end
    else
      nwday = (date - number).wday
      while (meet_day = Center.meeting_days.index(meeting_day_for(date - number)) and meet_day > 0 and nwday != meet_day)
        number += 1
        nwday = (date - number).wday
        nwday = 7 if nwday == 0
      end
    end
    return number
  end

  def convert_blank_to_nil
    self.attributes.each{|k, v|
      if v.is_a?(String) and v.empty? and self.class.properties.find{|x| x.name == k}.type==Integer
        self.send("#{k}=", nil)
      end
    }
  end

end
