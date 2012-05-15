require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe "Grameen" do
  before :all do
    Center.all.destroy!
    @loan_product = Factory(:loan_product)
    
    @center = Factory.build(:center, :creation_date => Date.new(2012,5,2))
    @center.save
    @client = Factory.create(:client, :center => @center)

  end

  it "should calculate stub dates properly" do
    @loan_product.loan_validation_methods = "collect_stub_period_interest"
    @loan_product.save
    d1 = Date.new(2012,5,15) # tuesday
    d2 = Date.new(2012,5,30)  # wednesday
    @loan = Factory.create(:approved_loan, :scheduled_disbursal_date => d1, :scheduled_first_payment_date => d1 + 15, :loan_product => @loan_product, :client => @client)
    @loan.save
    @cmd = @center.center_meeting_days.first
    @cmd.of_every = 2
    @cmd.save!
    @center.reload
    @loan.reload
    @loan.stub_dates.should == [d1 + 1]
    @loan.installment_dates.should include(d1 + 1)
  end
end
