require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Center do

  before(:all) do
    StaffMember.all.destroy!
    User.all.destroy!
    Branch.all.destroy!
    Center.all.destroy!
    Client.all.destroy!
    @manager = Factory(:staff_member)
    @manager.should be_valid

    @user = Factory(:user)
    @user.should be_valid

    @branch = Factory(:branch, :manager => @manager)
    @branch.should be_valid

  end

  before(:each) do
    repository.adapter.execute("truncate table centers") # truncate resets the ids as well. this ensures that the catalog test passescata
    CenterMeetingDay.all.destroy!
    @center = Center.new(:name => "Munnar hill center")
    @center.manager = @manager
    @center.branch = @branch
    @center.creation_date = Date.new(2010, 1, 1)
    @center.meeting_day = :monday
    @center.code = "center"
    @center.save
    @center.should be_valid
  end
  
  it "should not be valid without a manager" do
    @center.manager = nil
    @center.should_not be_valid
  end
  
  it "should not be valid without a name" do
    @center.name = nil
    @center.should_not be_valid
  end

  it "should catalog correctly" do
    @branch_1 = Factory(:branch, :name => "Branch 1", :manager => @manager)
    @branch_2 = Factory(:branch, :name => "Branch 2", :manager => @manager)
    @b1c1 = Factory(:center, :name => "b1c1", :branch => @branch_1)
    @b1c2 = Factory(:center, :name => "b1c2", :branch => @branch_1)
    @b2c1 = Factory(:center, :name => "b2c1", :branch => @branch_2)
    @b2c2 = Factory(:center, :name => "b2c2", :branch => @branch_2)
    Center.catalog.should == {"Hyderabad center 1"=>{1=>"Munnar hill center"}, "Branch 1"=>{2=>"b1c1", 3=>"b1c2"}, "Branch 2"=>{5=>"b2c2", 4=>"b2c1"}}
  end


  # testing of center meeting days.
  # upon creation, a CenterMeetingDate is assigned to the center. It has blank valid_from and valid_upto fields.
  # The default date vector returned for this center is from creation_date until SEP_DATE (someone else's problem date) field
  # after this, center meeting days may be added and removed at will.


  it "should have meeting_days" do
    @center.center_meeting_days.length.should eql(1)
    @center.center_meeting_days.first.meeting_day.should == :monday
    @center.center_meeting_days.first.what.should == :monday
  end

  describe "calendar" do
    before :all do
      @center = Factory.create(:center)
      @calendar_input = Date.today..Date.today+10
      @bad_input      = %w(abc def ghi)
    end

    describe "with valid inputs" do
      before :all do
        @center.meeting_calendar = @calendar_input
      end

      it "should accept a list of dates as a calendar" do
        @center.calendar.should == nil
      end

    end
      
    describe "with invalid input" do
      before :each do
        @center.meeting_calendar = @bad_input
      end
      
      it "should be nil" do
        @center.calendar.should == nil
      end

      it "should invalidate the center" do
        @center.should_not be_valid
      end
    end
  end
      
      

  it "should give correct meeting days in this instance" do
    start_date = Date.new(2010,1,1)
    start_date = start_date - start_date.cwday + 8
    start_date.weekday.should == :monday
    date = start_date
    result = [date]
    while date <= SEP_DATE
      date += 7
      result << date if date <= SEP_DATE
    end
    @center.meeting_dates.should == result

    # then check for meeting dates where to is an integer
    r2 = @center.meeting_dates(10)
    r2.should == result[0..9]

    # then check for meeting dates where to is a date
    r2 = @center.meeting_dates(Date.new(2010,12,31))
    r2.should == result.select{|d| d <= Date.new(2010,12,31)}

    # check with a from date
    r2 = @center.meeting_dates(Date.new(2010,12,31), Date.new(2010,11,01))
    r2.should == result.select{|d| d <= Date.new(2010,12,31) and d >= Date.new(2010,11,01)}

    # check corner cases
    @center.meeting_dates(start_date, start_date).should == [start_date]
  end


  it "next and previous meeting dates should be correct" do
    center =  Center.create(:branch => @branch, :name => "center 75", :code => "c75", :creation_date => Date.new(2010, 03, 17),
                            :meeting_day => :wednesday, :manager => @manager)
    center.should be_valid
    center.next_meeting_date_from(Date.new(2010, 6, 30)).should   == Date.new(2010, 7, 7)
    center.next_meeting_date_from(Date.new(2010, 7, 1)).should    == Date.new(2010,  7, 7)
    center.next_meeting_date_from(Date.new(2010, 7, 3)).should    == Date.new(2010,  7, 7)
    center.next_meeting_date_from(Date.new(2010, 7, 5)).should    == Date.new(2010,  7, 7)
    center.next_meeting_date_from(Date.new(2010, 7, 6)).should    == Date.new(2010,  7, 7)

    center.previous_meeting_date_from(Date.new(2010, 7, 7)).should == Date.new(2010, 6, 30)
    center.previous_meeting_date_from(Date.new(2010, 7, 12)).should == Date.new(2010, 7, 07)
    center.previous_meeting_date_from(Date.new(2010, 7, 6)).should == Date.new(2010, 6, 30)
    center.previous_meeting_date_from(Date.new(2010, 7, 1)).should == Date.new(2010, 6, 30)

    center.next_meeting_date_from(Date.new(2010, 7, 7)).should     == Date.new(2010, 7, 14)
    center.next_meeting_date_from(Date.new(2010, 7, 10)).should    == Date.new(2010, 7, 14)
    center.next_meeting_date_from(Date.new(2010, 7, 12)).should    == Date.new(2010, 7, 14)

    center.next_meeting_date_from(Date.new(2010, 7, 10)).should    == Date.new(2010, 7, 14)
    center.next_meeting_date_from(Date.new(2010, 7, 11)).should    == Date.new(2010, 7, 14)
    center.next_meeting_date_from(Date.new(2010, 7, 12)).should    == Date.new(2010, 7, 14)

    center.next_meeting_date_from(Date.new(2010, 7, 13)).should    == Date.new(2010, 7, 14)
    center.next_meeting_date_from(Date.new(2010, 7, 15)).should    == Date.new(2010, 7, 21)
    center.next_meeting_date_from(Date.new(2010, 7, 19)).should    == Date.new(2010, 7, 21)

    center.previous_meeting_date_from(Date.new(2010, 7, 20)).should == Date.new(2010, 7, 14)
    center.previous_meeting_date_from(Date.new(2010, 7, 19)).should == Date.new(2010, 7, 14)
    center.previous_meeting_date_from(Date.new(2010, 7, 14)).should == Date.new(2010, 7, 7)

    center.previous_meeting_date_from(Date.new(2010, 7, 13)).should == Date.new(2010, 7, 7)
    center.previous_meeting_date_from(Date.new(2010, 7, 12)).should == Date.new(2010, 7, 7)
    center.previous_meeting_date_from(Date.new(2010, 7, 8)).should == Date.new(2010, 7, 7)
  end

  it "should accept date changes properly" do
    @center.center_meeting_days << CenterMeetingDay.new(:meeting_day => :thursday, :valid_from => Date.new(2010,10,17))
    @center.should be_valid
    @center.save
    # reload the center to see if it worked
    @center = Center.get(@center.id)
    @center.center_meeting_days.count.should == 2
    @center.meeting_dates(Date.new(2010,10,31), Date.new(2010,10,1)).should == [4,11,21,28].map{|d| Date.new(2010,10,d)}
  end

  it "should return correct meeting_day_for" do
    @cmd = CenterMeetingDay.new(:meeting_day => :tuesday, :valid_from => Date.today, :center => @center)
    @cmd.should be_valid
    @cmd.save
    @cmd2 = CenterMeetingDay.new(:meeting_day => :wednesday, :valid_from => Date.today + 10, :center => @center)
    @cmd2.should be_valid
    @cmd2.save
    @center = Center.get(@center.id) # reload
    @center.center_meeting_day_for(Date.today - 1).what.should == :monday
    @center.center_meeting_day_for(Date.today).what.should == :tuesday
    @center.center_meeting_day_for(Date.today + 10).what.should == :wednesday
  end

  it "should return correct value for meeting_day?" do
    start_date = Date.new(2010,1,4)
    @center.meeting_day?(start_date).should == true
    @center.meeting_day?(start_date + 1).should == false
    @center.meeting_day?(start_date + 7).should == true
  end

  it "should show up properly in Branch#centers_With_paginate" do
    repository.adapter.execute("truncate table branches") # truncate resets the ids as well. this ensures that the catalog test passescata
    repository.adapter.execute("truncate table centers")
    repository.adapter.execute("truncate table center_meeting_days")
    
    @branch_1 = Factory(:branch, :name => "Branch 1", :manager => @manager)
    @branch_2 = Factory(:branch, :name => "Branch 2", :manager => @manager)
    @b1c1 = Center.create(:name => "b1c1", :branch => @branch_1, :meeting_day => :monday, :manager => @manager, :code => "a")
    @b1c2 = Center.create(:name => "b1c2", :branch => @branch_1, :meeting_day => :tuesday, :manager => @manager, :code => "b")
    @b2c1 = Center.create(:name => "b2c1", :branch => @branch_2, :meeting_day => :tuesday, :manager => @manager, :code => "c")
    @b2c2 = Center.create(:name => "b2c2", :branch => @branch_2, :meeting_day => :thursday, :manager => @manager, :code => "d")
    
    Branch.first.centers_with_paginate({:meeting_day => :tuesday}, Factory(:user)).aggregate(:id).should == [2]
    
  end

  it "should not be valid with a name shorter than 3 characters" do
    @center.name = "ok"
    @center.should_not be_valid
  end
  
  it "should be able to 'have' clients" do
    
    user = Factory(:user, :role => :mis_manager)
    user.should be_valid
    
    client = Factory(:client, :center => @center, :created_by => user)
    client.errors.each {|e| p e}
    client.should be_valid
    
    @center.clients.count.should eql(1)
    
    client2 = Factory(:client, :center => @center, :created_by => user)
    client2.errors.each {|e| p e}
    client2.should be_valid
    
    @center.clients.count.should eql(2)
  end
  
end
