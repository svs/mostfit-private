require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe LoanCenterMembership do
  before(:all) do
    [StaffMember, Branch, Center, User, LoanProduct, Loan, ClientCenterMembership].each{|x| x.all.destroy!}
    @manager = Factory(:staff_member)
    @manager.save
    
    @branch = Factory(:branch, :manager => @manager)
    @branch.should be_valid

    @center = Factory(:center, :manager => @manager, :branch => @branch)
    @center.should be_valid

    @center2 = Factory(:center, :manager => @manager, :branch => @branch)
    @center2.should be_valid

    @user = Factory(:user)
    @user.should be_valid

    @loan_product = Factory(:loan_product)
    @loan_product.should be_valid

    @client_type = Factory(:client_type)

    @client = Factory(:client, :center => @center)
  end

  before(:each) do
    Loan.all.destroy!
  end

  it "should not be valid without any values in it" do
    @lcm1 = LoanCenterMembership.new
    @lcm1.should_not be_valid
  end
  
  describe "valid membership" do
    before :all do
      LoanCenterMembership.all.destroy!
      ClientCenterMembership.all.destroy!
      Client.all.destroy!; Loan.all.destroy!; Center.all.destroy!
      @center = Factory(:center, :manager => @manager, :branch => @branch)
      @client = Factory(:client, :center => @center)
      @loan = Factory.build(:loan, :client => @client)
      @loan.save
      @lcm1 = @loan.loan_center_memberships[0]
    end
    it "a membership should be automatically assigned upon loan creation" do
      @loan.loan_center_memberships.count.should == 1
    end
    it "should be valid with a loan and a center" do
      @lcm1.member.should == @loan
      @lcm1.club.should == @loan.center
      @lcm1.should be_valid
    end

    it "should take as default 1 Jan 1900 as from date" do
      @lcm1.from.should == Date.new(2000,2,1)
    end
    it "should take SEP_DATE as default upto date" do
      @lcm1.upto.should == SEP_DATE
    end
  end

  describe "as of" do
    before :each do
      Loan.all.destroy!
      LoanCenterMembership.all.destroy!
      @loan = Factory.build(:loan, :client => @client, :center => @center)
      @loan.save
      @lcm1 = LoanCenterMembership.first
    end
    
    it "should give correct as of date for single model" do
      @loan.loan_center_memberships.as_of(Date.today).should == @center.id
    end

    it "should give correct as of date for multiple models with end date on all but one" do
      @lcm1.upto = Date.today + 10
      @lcm1.save
      @center2 = Factory.create(:center)
      @lcm2 = LoanCenterMembership.create(:member => @loan, :club => @center2, :from => Date.today + 11)
      @lcm2.should be_valid
      @loan.loan_center_memberships.as_of(Date.today).should == @center.id
      @loan.loan_center_memberships.as_of(Date.today + 10).should == @center.id
      @loan.loan_center_memberships.as_of(Date.today + 15).should == @center2.id
    end
    
    
  end

end
