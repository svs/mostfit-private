require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe CenterMeetingDay do

  before(:all) do
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
    @center_meeting_day = CenterMeetingDay.new(:meeting_day => :thursday)
    @center.center_meeting_days << @center_meeting_day
    @center.save
    @center.should be_valid
    @center.errors.each{|e| puts e}
  end

  it "should be valid with a meeting day" do
    @center_meeting_day.valid?
    @center_meeting_day.errors.each{|e| puts e}
    @center_meeting_day.should be_valid

    @center_meeting_day.meeting_day = nil
    @center_meeting_day.should_not be_valid
  end

  it "should work correctly when added to a center with existing center_meeting_days" do
    @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center)
    @cmd2.should_not be_valid # because the center already has one CMD without valid_from and valid_upto

    @cmd2.valid_from = Date.today
    @cmd2.should be_valid

    @cmd2.valid_from = nil
    @cmd2.valid_upto = Date.today
    @cmd2.should_not be_valid  # only the first CMD can have a nil valid_from
  end

  it "should check that center meeting dates do not overlap" do
    # should not be valid wthout valid_from
    @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center)
    @cmd2.should_not be_valid
    # should be valid with a valid_From and without valid_upto
    @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today)
    @cmd2.should be_valid
    @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today, :valid_upto => Date.today + 30)
    @cmd2.should be_valid
    @cmd2.save
    # reload the center and try with an overlapping date
    @center = Center.get(@center.id)
    @cmd3 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today + 15, :valid_upto => Date.today + 45)
    @cmd3.should_not be_valid
    # check the corner case
    @cmd3.valid_from = Date.today + 30
    @cmd3.should_not be_valid
    # now check with valid interval
    @cmd3.valid_from = Date.today + 31
    @cmd3.should be_valid
    @cmd3.save
    # try deleting a center meeting day
    @cmd3.destroy
    @center = Center.get(@center.id)
    @center.center_meeting_days.count.should == 2
  end

  it "should return correct centers meeting days in force on a given date" do
    @branch_1 = Factory(:branch, :name => "Branch 1", :manager => @manager)
    @branch_2 = Factory(:branch, :name => "Branch 2", :manager => @manager)
    @b1c1 = Center.create(:name => "b1c1", :branch => @branch_1, :meeting_day => :monday, :manager => @manager, :code => "a")
    @b1c2 = Center.create(:name => "b1c2", :branch => @branch_1, :meeting_day => :tuesday, :manager => @manager, :code => "b")
    @b2c1 = Center.create(:name => "b2c1", :branch => @branch_2, :meeting_day => :wednesday, :manager => @manager, :code => "c")
    @b2c2 = Center.create(:name => "b2c2", :branch => @branch_2, :meeting_day => :thursday, :manager => @manager, :code => "d")
    
    centers = [@b1c1, @b1c2, @b2c1, @b2c2]

    CenterMeetingDay.in_force_on(Date.today, centers).should == CenterMeetingDay.all[-4..-1]
    
  end

end
