class CenterMeetingDay

  include DataMapper::Resource
  DAYS = [:none, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  before :valid?, :convert_blank_to_nil
  before :valid?, :set_date_vector_properties
  after :destroy, :fix_dates
  after :save,    :add_loans_to_queue

  property :id, Serial
  property :center_id, Integer, :index => false, :nullable => false
  property :meeting_day, Enum.send('[]', *DAYS), :nullable => false, :default => :none, :index => true
  property :valid_from,  Date, :nullable => true # if nil then this must be the first CMD for the center
  property :valid_upto,  Date, :nullable => true # we do not really need valid upto.  CMDs are valid up to the next center meeting days start from
  
  property :deleted_at,  ParanoidDateTime
  
  # define some properties using which we can construct a DateVector of meeting dates
  # see lib/date_vector.rb for details but in short one can say things like
  # :every => [2,4], :what => :thursday, :of_every => 2, :period => :month to mean "every 2nd and 4th thursday of every 2nd month"
  # this is the kind of feature that sets Mostfit miles apart from the rest of the pack!
  # for now we will allow only one datevector type per center. This means a center can only have one meeting schedule frequency

  property :every, CommaSeparatedList 
  property :what, Enum.send('[]',*([:day] + DAYS[1..-1]))
  property :of_every, Integer
  property :period, Enum[nil,:week, :month], :nullable => true

  # end datevector properties

  # RELATIONSHIPS
  belongs_to :center

  # VALIDATIONS
  validates_with_method :either_meeting_day_or_date_vector
  validates_with_method :valid_from_is_lesser_than_valid_upto
  validates_with_method :dates_do_not_overlap
  validates_with_method :check_not_last, :if => Proc.new{|t| t.deleted_at}

  # REPRESENTATION
  # Public: Returns a short String representation of the center meeting date
  def to_s
    meeting_day_string
  end

  # Public: returns a longer String representation of the center meeting date
  def desc
    "from #{valid_from} to #{valid_upto} : #{meeting_day_string}"
  end
  
  # Public: Returns a String representation of the meeting day
  def meeting_day_string
    return meeting_day.to_s if meeting_day and meeting_day != :none
    "#{every.join(',')} #{what} of every #{of_every} #{period}" rescue meeting_day
  end

  # Public: Returns the weekday of the meeting day 
  # 
  # some complications arise due to the fact that the meeting day can be specified either on the :meeting_day
  # parameter or even on the :what parameter
  def meeting_wday
    return meeting_day if meeting_day and meeting_day != :none
    return what if what != :day
    return period if period == :month
    return meeting_day
  end


  # DATES

  # Public: returns the last Date upto which this CenterMeetingDay is valid
  def last_date
    valid_upto || SEP_DATE
  end


  # Public: creates and return a DateVector which matches this CenterMeetingDay schedule
  def date_vector(from = self.valid_from, to = last_date)
    if every and what and of_every and period
      DateVector.new(every, what, of_every, period.to_sym, from, to)
    else
      DateVector.new(1,meeting_day, 1, :week, from, to)
    end
  end

  def get_dates(from = self.valid_from, to = last_date)
    # DEPRECATED use #meeting_dates instead
    meeting_dates(from, to)
  end

  # Public: returns an array of Dates representing the meeting dates covered by this CenterMeetingDay
  def meeting_dates(from = self.valid_from, to = last_date)
    date_vector(from, to).get_dates
  end

  # Public: returns an array of the next 'n' dates for this CenterMeetingDay
  #
  # n: an Integer - how many dates you want?
  # from: an optional Date setting the lower bound of the dates
  def get_next_n_dates(n, from = self.valid_from)
    get_dates(from, n)
  end

  # SEARCH
  
  # Public: returns the center meeting days in force on a particular day for a particular list of centers
  #
  # date: the Date for which the list is required
  # centers: a Hash specifiying the selection or a DataMapper::Collection of centers to filter for
  # meeting_day: an optional Symbol for meeting_day for which to filter the list
  #
  # Examples
  # CenterMeetingDay.in_force_on(Date.today, Center.all(:id => 1))
  def self.in_force_on(date, centers = {}, meeting_day = nil)
    center_ids = centers.is_a?(Hash) ? Center.all(centers).aggregate(:id) : centers.aggregate(:id)
    raise ArgumentError.new("Strange weekday you got") if meeting_day and (not WEEKDAYS.include?(meeting_day))
    meeting_day_selection = WEEKDAYS.include?(meeting_day) ? {:what => meeting_day} : {}
    # first get the CMDs with both valid_from and valid_upto
    # there will only be one for each center because they cannot overlap
    c1 = CenterMeetingDay.all(meeting_day_selection.merge(:valid_from.lte => date, :valid_upto.gte => date, :center_id => center_ids))
    center_ids = center_ids - c1.aggregate(:center_id)
    rv = c1
    # then get the CMDs with valid_From = nil with proper valid_upto which are not in the above array
    unless center_ids.blank?
      c2 = CenterMeetingDay.all(meeting_day_selection.merge(:valid_from => nil, :valid_upto.gte => date, :center_id => center_ids)) 
      center_ids = center_ids - c2.aggregate(:center_id)
      # now the above can contain multiple lines per center, so deal with that
      c2 = c2.group_by{|c| c.center_id}.map{|cid, c| c.sort_by{|_c| _c.valid_from}[-1]}
      rv += c2
    end
    unless center_ids.blank?
      # then get the CMDs with valid_From  without proper valid_upto which are not in the above array
      c3 = CenterMeetingDay.all(meeting_day_selection.merge(:valid_from.lte => date, :valid_upto => nil, :center_id => center_ids)) unless center_ids.blank?
      center_ids = center_ids - c3.aggregate(:center_id)
      # now the above can contain multiple lines per center, so deal with that
      c3 = c3.group_by{|c| c.center_id}.map{|cid, c| c.sort_by{|_c| _c.valid_from}[-1]}
      rv += c3
    end
    # then get the CMDs with no valid_upto either
    unless center_ids.blank?
      c4 = CenterMeetingDay.all(meeting_day_selection.merge(:valid_from => nil, :valid_upto => nil, :center_id => center_ids))
      rv += c4
    end
    rv
    
  end
  
  private
  
  # adds the loans from this center into the dirty_loan queue to recreate their history
  def add_loans_to_queue
    loan_ids = self.center.loans.aggregate(:id) rescue nil
    return if loan_ids.blank?
    now = DateTime.now
    repository.adapter.execute(get_bulk_insert_sql("dirty_loans", loan_ids.map{|pl| {:loan_id => pl, :created_at => now}}))
    DirtyLoan.send(:class_variable_set,"@@poke_thread", true)
  end


  # Private: 
  def fix_dates
    cmds = CenterMeetingDay.all(:order => [:valid_from], :center_id => self.center_id)
    cmds.each_with_index{|cmd, idx|
      cmd.valid_upto=Date.new(2100, 12, 31) if cmds.length - 1 == idx
      
      if idx==0
        if cmd.valid_from>cmd.center.creation_date
          cmd.valid_from=cmd.center.creation_date
        end
      else
        if cmds[idx-1].valid_upto+1 != cmd.valid_from
          cmd.valid_from = cmds[idx-1].valid_upto+1
        end
      end
      cmd.save
    }
    # fix center meeting day
    cen = Center.get(self.center_id)
    if cen.meeting_day != cen.meeting_day_for(Date.today)
      cen.meeting_day  = cen.meeting_day_for(Date.today)
      cen.save
    end
  end

  # Private: substitues nil in the valid_from and valid_upto fields with suitably improbable dates
  def substitute_nils_for_dates
    self.valid_from = Date.min_date unless self.valid_from
    self.valid_upto = SEP_DATE unless self.valid_upto
  end

  def convert_blank_to_nil
    self.attributes.each{|k, v|
      if v.is_a?(String) and v.empty? and [Integer, Enum].include?(self.class.properties.find{|x| x.name == k}.type)
        self.send("#{k}=", nil)
      end
    }
    self.period = self.period.to_sym rescue nil
  end

  # Private: ensures that every CMD has a valid datevector so we can depend only on those properties
  # for our calculations and representations
  def set_date_vector_properties
    if meeting_day and meeting_day != :none
      self.every = "1"; self.what = self.meeting_day; self.of_every = 1; self.period = :week
    else
      self.every = self.what = self.meeting_day = self.of_every = self.period = nil
    end
  end

  # VALIDATIONS
  # Private: checks that the valid from date is less than the valid upto dates, adjusting for nils
  def valid_from_is_lesser_than_valid_upto
    return true if self.valid_from.blank? and self.valid_upto.blank? # neither is set
    self.valid_from = Date.parse(self.valid_from) if self.valid_from.is_a?(String)
    self.valid_upto = (self.valid_upto.blank? ? SEP_DATE : Date.parse(self.valid_upto))     if self.valid_upto.class == String

    if self.valid_from and self.valid_upto
      return [false, "Valid from date cannot be before than valid upto date"] if self.valid_from > self.valid_upto
    end
    return true    
  end

  # Private: checks that for a given center, the valid_from and valid_to dates for this center do not overlap with another center_meeting_day
  def dates_do_not_overlap
    return true if deleted_at
    return true unless self.center
    cmds = self.center.center_meeting_days
    return true if cmds.count == 0
    if cmds.count == 1
      return true  if cmds.first.id == self.id
      if cmds.first.valid_from == nil
        return true if self.valid_from
        return [false, "This Center Meeting Schedule definition must have a valid_from date set"]
      end
    end
    bad_ones = center.center_meeting_days.map do |cmd| 
      if cmd.id == id
        true
      else
        if cmd.valid_upto and cmd.valid_upto != SEP_DATE                                                             # an end date is specified for the other cmd 
          if valid_upto  and valid_upto != SEP_DATE                                                                  # and for ourselves
            valid_from ? (cmd.valid_from > valid_upto or  cmd.valid_upto < valid_from) : cmd.valid_from > valid_upto # either we end before the other one starts or start after the other one ends
          else                                                                                                       # but not for ourselves
            valid_from > cmd.valid_upto or valid_from < cmd.valid_from                                               # either we start after the other one starts or we start after the other one ends
          end
        else                                                                                                         # no end date specified for the other one
          if valid_upto and  valid_upto != SEP_DATE                                                                  # but we have one
            cmd.valid_from ? (valid_from > cmd.valid_from or valid_upto < cmd.valid_from) : true                     # either we start after the other one starts or we end before the other one starts
          else                                                                                                       # neither one has an end date
            true
          end
        end
      end
    end
    return [false, "Center Meeting Day validity overlaps with another center meeting day."] if bad_ones.select{|x| not x}.count > 0
    return true
  end


  # Private: checks that user has specified either a meeting_day or a valid datevector
  def either_meeting_day_or_date_vector
    date_vector_valid = every and (not every.blank?) and what and (not what.blank?) and of_every and (not of_every.blank?) and period and (not period.blank?)
    return true if meeting_day or date_vector_valid
    return [false, 'Choose either a meeting day or a scheme to set up a schedule']
  end

  # Private: ensures that one cannot delete the last center_meeting_day for a center
  def check_not_last
    return true unless center
    return true unless deleted_at
    return [false,"cannot delete the last center meeting date"] if (self.center.center_meeting_days.count == 1 and (self.center.meeting_day == :none or (not self.center.meeting_day)))
    return true
  end
  

end
