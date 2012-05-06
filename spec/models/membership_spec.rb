require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe ClientCenterMembership do
  before(:all) do
    [StaffMember, Branch, Center, User, LoanProduct, Loan, ClientCenterMembership].each{|x| x.all.destroy!}
    @manager = Factory(:staff_member)
    @manager.save
    
    @branch = Factory(:branch, :manager => @manager)
    @branch.should be_valid

    @center = Factory(:center, :manager => @manager, :branch => @branch)
    @center.should be_valid

    @user = Factory(:user)
    @user.should be_valid

    @loan_product = Factory(:loan_product)
    @loan_product.should be_valid

    @client_type = Factory(:client_type)
  end

  before(:each) do
    Client.all.destroy!
  end

  it "should give correct club_model" do
    ClientCenterMembership.club_model.should == :center_id
  end


  it "should not be valid without any values in it" do
    @ccm1 = ClientCenterMembership.new
    @ccm1.should_not be_valid
  end
  
  describe "valid membership" do
    before :all do
      ClientCenterMembership.all.destroy!
      @client = Factory.build(:client, :center => @center)
      @client.save!
      @center.save!
      @ccm1 = ClientCenterMembership.new(:client => @client, :center => @center)
    end
    it "should be valid with a client and a center" do
      @ccm1.should be_valid
    end
    it "should take as default 1 Jan 1900 as from date" do
      @ccm1.from.should == Date.new(1900,1,1)
    end
    it "should take SEP_DATE as default upto date" do
      @ccm1.upto.should == SEP_DATE
    end
  end

  describe "multiple membership" do
    before :each do
      Center.all.destroy!
      ClientCenterMembership.all.destroy!
      @client = Factory.build(:client, :center => @center)
      @client.save!
      @center.save!
      @ccm1 = ClientCenterMembership.first
      @center2 = Factory.create(:center)
    end

    it "should allow client to have membership in multiple centers" do
      @ccm2 = ClientCenterMembership.new(:client => @client, :center => @center2)
      @ccm2.should be_valid
    end      
    
    it "should have a correct idea of its peers" do
      debugger
      @ccm2 = ClientCenterMembership.new(:client => @client, :center => @center2)
      @ccm2.send(:peers).should == [@ccm1]
    end
    
    it "should recognise overlaps correctly" do
      @ccm1.upto = Date.today + 10
      @ccm1.save
      @ccm2 = ClientCenterMembership.create(:client => @client, :center => @center2, :from => Date.today + 11)
      ClientCenterMembership.count.should == 2
      @ccm2.overlap?(@ccm2.send(:peers)).should == false
      @ccm2.from = Date.today + 10
      @ccm2.overlap?(@ccm2.send(:peers)).should == true
    end

    it "should recognise empty space correctly" do
      # @ccm1.upto = Date.today + 10
      # @ccm1.save
      # @ccm2 = ClientCenterMembership.create(:client => @client, :center => @center2, :from => Date.today + 11, :upto => Date.today + 15)
      # @ccm3 = ClientCenterMembership.create(:client => @client, :center => @center2, :from => Date.today + 16)
      # ClientCenterMembership.count.should == 3
      # @ccm2.gaps?(@ccm2.send(:peers)).should == false
      # @ccm2.from = Date.today + 12
      # @ccm2.gaps?(@ccm2.send(:peers)).should == true
    end    

    it "should not allow a client to be without membership at any time" do
      # @ccm1.upto = Date.today + 10
      # @ccm1.save
      # @ccm2 = ClientCenterMembership.create(:client => @client, :center => @center2, :from => Date.today + 20)
      # @ccm2.should_not be_valid
    end
  end

  describe "as of" do
    before :each do
      Center.all.destroy!
      ClientCenterMembership.all.destroy!
      @client = Factory.build(:client, :center => @center)
      @client.save!
      @center.save!
      @ccm1 = ClientCenterMembership.first
    end
    
    it "should give correct as of date for single model" do
      @client.client_center_memberships.as_of(Date.today).should == [@center.id]
    end

    it "should give correct as of date for multiple models" do
      @center2 = Factory.create(:center)
      @ccm2 = ClientCenterMembership.create(:client => @client, :center => @center2)
      Set.new(@client.client_center_memberships.as_of(Date.today)).should == Set.new([@center.id, @center2.id])
    end

    it "should give correct as of date for multiple models with end date on all but one" do
      @ccm1.upto = Date.today + 10
      @ccm1.save
      @center2 = Factory.create(:center)
      @ccm2 = ClientCenterMembership.create(:client => @client, :center => @center2, :from => Date.today + 10)
      @ccm2.should be_valid
      @client.client_center_memberships.as_of(Date.today).should == [@center.id]
      @client.client_center_memberships.as_of(Date.today + 10).should == [@center.id,@center2.id]
      @client.client_center_memberships.as_of(Date.today + 15).should == [@center2.id]
    end
    
    
  end

end
