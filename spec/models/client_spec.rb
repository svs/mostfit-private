require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Client do

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
    @client = Factory.build(:client, :center => @center)
    @client.should be_valid
    @client.save
  end

  describe "centers" do
    it "should have a CenterMembership" do
      @client.client_center_memberships.count.should == 1
    end
    it "'s initial center membership must start on the joining date and never end" do
      @client.client_center_memberships.first.from.should == @client.date_joined
    end

    describe "adding another center" do
      before :all do
        @center2 = Factory(:center, :manager => @manager, :branch => @branch)
      end
      it "should not be duplicated" do
        @client.center = [@center, @client.date_joined]
        @client.client_center_memberships.count.should == 1
      end
      it "adds a center_membership when properly called" do
        @client.center= [@center, (Date.today + 10)]
        @client.client_center_memberships.length.should == 2
      end
      describe "listing memberships" do
        before :all do
          Client.all.destroy!
          ClientCenterMembership.all.destroy!
          @client = Factory.build(:client, :center => @center)
        end
        before :each do
          @client.center= [@center2, (Date.today + 10)]
          @client.save
        end
        it "should give correct center_as_of" do
          @client.center.should == [@center]
        end
        it "should give correct center as_of in the future" do
          Set.new(@client.center(Date.today + 15)).should == Set.new([@center2,@center])
        end
        it "should respect membership end dates" do
          cm = @client.client_center_memberships.first
          cm.upto = Date.today + 15
          cm.save
          @client.reload
          @client.center.should == [@center]
          @client.center(Date.today + 12).should == [@center, @center2]
          @client.center(Date.today + 20).should == [@center2]
        end
      end
    end
  end
  

  it "should not be valid without belonging to a center" do
    expect {@client.center = nil}.to raise_error
  end

  it "should not be valid without a name" do
    @client.name = nil
    @client.should_not be_valid
  end

  it "should not be valid without a reference" do
    @client.reference = nil
    @client.should_not be_valid
  end

  it "should not be valid with name shorter than 3 characters" do
    @client.name = "ok"
    @client.should_not be_valid
  end

  it "should have a joining date" do
    @client.date_joined = nil
    @client.should_not be_valid
  end

  it "should be able to 'have' loans" do
    @client.save
    loan = Factory.build(:loan, :applied_by => @manager, :client => @client, :amount => 1000, :installment_frequency => :weekly)
    loan.save
    loan.should be_valid

    @client.loans << loan
    @client.save
    @client.loans.first.amount.to_i.should eql(1000)
    @client.loans.first.installment_frequency.should eql(:weekly)

    loan2 = Factory.build(:loan, :applied_by => @manager, :approved_by => @manager, :approved_on => Date.new(2010, 01, 01), :client => @client)
    loan2.save
    loan2.should be_valid

    @client.loans << loan2
    @client.save  # Datamapper doesn't automatically save after adding a loan
    @client.should be_valid
    # Make sure to use count and not size to check the actual database records, not just the in-memory object
    @client.loans.count.should eql(2)
  end
 
  it "should not be deleteable if verified" do
    @client.verified_by = @user
    @client.save
    @client.destroy.should be_false

    @client.verified_by = nil
    @client.destroy.should be_true
  end

  # There are no assertions here...
  it "should deal with death of a client" do
    @client.deceased_on = Date.today
  end

end
