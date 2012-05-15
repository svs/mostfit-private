require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe "ValidationHooks" do

  before :all do
    [User,Loan, LoanProduct, Payment, LoanHistory, StaffMember,Branch, Center, Client, RepaymentStyle, LoanProduct, Fee].each do |x|
      x.all.destroy!
    end
    @user = Factory(:user)
    @user.should be_valid
    
    @manager = Factory(:staff_member)
    @manager.should be_valid
    
    @funding_line = Factory(:funding_line)
    @funding_line.should be_valid
    
    @branch = Factory(:branch, :manager => @manager)
    @branch.should be_valid
    
    @center = Factory(:center, :manager => @manager, :branch => @branch, :meeting_day => :wednesday, :creation_date => Date.new(1999,12,31))
    @center.should be_valid
    @center.save
    
    @client = Factory(:client, :center => @center, :created_by_user_id => @user.id)
    @client.save!
    
    RepaymentStyle.all.destroy!
    
    @flat = RepaymentStyle.new(:style => "Flat")
    @flat.save
    
    @loan_product = Factory.create(:loan_product, :repayment_style => @flat)
    
    @loan_product.should be_valid
    @loan = Factory.build(:approved_loan, :loan_product => @loan_product)
    @loan.should be_valid
    @loan.save
  end
  
  describe "hooks should actually hook" do

    it "should not add validators not defined in Foremost::LoanValidators to the LoanProduct model" do
      @loan_product.loan_validation_methods = "abc, def"
      @loan_product.save
      @loan.reload
      @loan.loan_product.loan_validations.should == []
    end
    
    it "should add properly defined validators to the LoanProduct model" do
      @loan_product.loan_validation_methods = "scheduled_dates_must_be_center_meeting_days, installments_are_integers?"
      @loan_product.save
      @loan_product.loan_validations.should == ["scheduled_dates_must_be_center_meeting_days", "installments_are_integers?"]
    end
    
    it "should hook defined validators into the loan" do
      @loan_product.loan_validation_methods = "scheduled_dates_must_be_center_meeting_days, installments_are_integers?"
      @loan_product.save
      @loan.reload
      @loan.model.validators.first[1].map{|x| x.options[:method]}.should include("scheduled_dates_must_be_center_meeting_days")
    end
  end

  describe Foremost::LoanValidators do
    it "should not be valid if duplicated" do
      @loan_product.loan_validation_methods = "loans_must_not_be_duplicated"
      @loan_product.save
      @loan2 = Loan.new(@loan.attributes.except(:id).merge(:loan_product => @loan_product))
      @loan2.should_not be_valid
    end


    describe "scheduled dates" do
      describe "without restriction" do
        it "should be valid if repayment dates are not center meeting dates" do
          @loan.scheduled_disbursal_date = Date.new(2000, 11, 30)
          @loan.should be_valid
          
          @loan.scheduled_disbursal_date = Date.new(2000, 11, 29)
          @loan.should be_valid
          
          @loan.disbursal_date = Date.new(2000, 11, 23)
          @loan.applied_by     = @manager
          @loan.disbursed_by   = @manager
          @loan.should be_valid
          
          @loan.disbursal_date = Date.new(2000, 12, 29)
          @loan.should be_valid
          
          @loan.disbursal_date = Date.new(2000, 12, 30)
          @loan.should be_valid
        end
      end
      
      describe "with validation scheduled_dates_must_be_center_meeting_days" do
        before :each do
          @loan = Factory.build(:approved_loan)
          @loan.save
          @loan_product = @loan.loan_product
          @loan_product.loan_validation_methods = "scheduled_dates_must_be_center_meeting_days"
          @loan_product.save
          @cmd = CenterMeetingDay.new(:meeting_day => :tuesday, :valid_from => @loan.scheduled_first_payment_date + 29, :center => @loan.center)
          @cmd.save
          @loan.reload
          @loan.clear_cache
        end
        
        it "should change with center meeting date change" do
          @loan.installment_dates[5..-1].map(&:weekday).uniq.should == [:tuesday]
        end
      end

      describe "with center meeting day restriction" do
        before :all do
          @loan_product.loan_validation_methods = "disbursal_dates_must_be_center_meeting_days"
          @loan_product.save
          @loan = Factory.build(:approved_loan, :loan_product => @loan_product)
        end
        
        it "should be valid on the same day" do
          @center.meeting_day_for(Date.new(2000, 11, 29)).should == :wednesday
          @loan.scheduled_disbursal_date = Date.new(2000, 11, 29)
          @loan.disbursal_date = nil
          @loan.disbursed_by   = nil
          @loan.should be_valid
          
          @loan.disbursal_date = Date.new(2000, 11, 22)
          @loan.disbursed_by   = @manager    
          @loan.should be_valid
          
        end
        
        it "should not be valid on another day" do
          @loan.disbursal_date = Date.new(2000, 11, 30)
          @loan.disbursed_by   = @manager
          @loan.should_not be_valid
          
          @loan.disbursal_date = Date.new(2000, 11, 02)
          @loan.disbursed_by   = @manager
          @loan.should_not be_valid
          
          @loan.disbursal_date = Date.new(2000, 11, 27)
          @loan.disbursed_by   = @manager
          @loan.should_not be_valid
        end
      end
      
    end

  end
end

