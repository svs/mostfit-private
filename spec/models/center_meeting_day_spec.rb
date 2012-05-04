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
    # actually this is something to be debated
    # the way I see it, we can have the following situation
    # first CMD     valid_from => nil, valid_upto => nil   # call this 'default' CMD
    # after that    valid_from => nil, valid_upto => d1    # i.e. this is in vogue from start until d1 and after that 'default' CMD
    # or            valid_upto => nil, valid_from => d2    # i.e. upto d2 default, then this one
    # if both are specified then, given d1 > d2, we cannot calculate a schedule so we cannot allow this scheme
    #                             given d2 > d1 we get d1, d2 and default is never used.....
    # or is this too confusing?
    # in the current scheme, as many CMDs can have nul valid_upto but only one CMD can have nil valid_from
    # which makes everything much simpler in my opinion

  end

  describe "overlap" do
    
    it "should should not be valid wthout valid_from" do
      @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center)
      @cmd2.should_not be_valid
    end
    it "should be valid with a valid_From and without valid_upto" do
      @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today)
      @cmd2.should be_valid
      @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today, :valid_upto => Date.today + 30)
      @cmd2.should be_valid
      @cmd2.save
    end
    describe "overlapping dates" do
      before :each do
        @center = Center.get(@center.id)
        @cmd2 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today, :valid_upto => Date.today + 30)
        @cmd2.should be_valid
        @cmd2.save
        @cmd3 = CenterMeetingDay.new(:meeting_day => :friday, :center => @center, :valid_from => Date.today + 15, :valid_upto => Date.today + 45)
      end
      it "should not be valid" do
        @cmd3.should_not be_valid
      end
      it "should not be valid on the edge" do
        @cmd3.valid_from = Date.today + 30
        @cmd3.should_not be_valid
      end
      it "should be valid with a valid interval" do
        @cmd3.valid_from = Date.today + 31
        @cmd3.should be_valid
      end
      it "should delete properly" do
        @cmd3.save
        @cmd3.destroy
        @center = Center.get(@center.id)
        @center.center_meeting_days.count.should == 2
      end
    end
  end

  it "should return correct centers meeting days in force on a given date" do
    repository.adapter.execute("truncate table centers") # truncate resets the ids as well. this ensures that the catalog test passescata
    repository.adapter.execute("truncate table center_meeting_days") # truncate resets the ids as well. this ensures that the catalog test passescata

    @branch_1 = Factory(:branch, :name => "Branch 1", :manager => @manager)
    @branch_2 = Factory(:branch, :name => "Branch 2", :manager => @manager)
    @b1c1 = Center.create(:name => "b1c1", :branch => @branch_1, :meeting_day => :monday, :manager => @manager, :code => "a")
    @b1c2 = Center.create(:name => "b1c2", :branch => @branch_1, :meeting_day => :tuesday, :manager => @manager, :code => "b")
    @b2c1 = Center.create(:name => "b2c1", :branch => @branch_2, :meeting_day => :tuesday, :manager => @manager, :code => "c")
    @b2c2 = Center.create(:name => "b2c2", :branch => @branch_2, :meeting_day => :thursday, :manager => @manager, :code => "d")
    
    centers = Center.all

    CenterMeetingDay.in_force_on(Date.today, centers).should == CenterMeetingDay.all
    
    @cmd = CenterMeetingDay.new(:center => @b1c1, :valid_from => Date.today, :meeting_day => :saturday)
    @cmd.should be_valid
    @cmd.save
    
    CenterMeetingDay.in_force_on(Date.today - 1, centers).should == CenterMeetingDay.all.to_a[0..-2]
    CenterMeetingDay.in_force_on(Date.today, centers).map(&:id).sort.should == CenterMeetingDay.all(:order => [:id]).to_a[1..-1].map(&:id).sort

    CenterMeetingDay.in_force_on(Date.today, centers, :tuesday).map(&:center_id).sort.should == [2,3]

    # now check what happens if we ask for in_force_on for a date beyond the last valid_upto date.
    # expected behaviour - if the center has CMD with valid_upto => nil, then that one will come back into effect after the validity date
    @cmd.valid_upto = Date.today + 10
    @cmd.should be_valid
    @cmd.save
    CenterMeetingDay.in_force_on(Date.today + 11, centers).map(&:id).sort.should == CenterMeetingDay.all(:order => [:id]).to_a[0..-2].map(&:id).sort

    @ocmd = CenterMeetingDay.first
    @ocmd.valid_upto = Date.today
    @ocmd.should_not be_valid # overlap with @cmd

    @ocmd.valid_upto = Date.today - 1
    @ocmd.should be_valid
    @ocmd.save
    CenterMeetingDay.in_force_on(Date.today + 11, centers).map(&:id).sort.should == CenterMeetingDay.all(:order => [:id]).to_a[1..-2].map(&:id).sort
    
  end

end
