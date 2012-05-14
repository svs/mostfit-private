require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Loan do
  before(:all) do   
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
    @loan = Factory.build(:loan, :loan_product => @loan_product)
    @loan.should be_valid
    @loan.save
  end

  describe "common stuff" do
    before(:each) do
      @approved_loan = Factory.build(:approved_loan, :client => @client)
      @approved_loan.should be_valid
    end

    it "should have a discrimintator" do
      @approved_loan.discriminator.should_not be_blank
    end

    it "should not be valid without belonging to a client" do
      @approved_loan.client = nil
      @approved_loan.should_not be_valid
    end

    it "should give error if amount is blank" do
      @approved_loan.amount = nil
      @approved_loan.should_not be_valid
    end

    describe "application" do
      before :each do
        @approved_loan.applied_by = @approved_loan.applied_on = nil
      end

      it "should have an `applied_on`" do
        @approved_loan.applied_by = @manager
        @approved_loan.should_not be_valid
      end
      
      it "should have an 'applied_by'" do
        @approved_loan.applied_on = Date.today
        @approved_loan.should_not be_valid
      end
      
      it "should be valid with both present" do
        @approved_loan.applied_on = "2000-01-01"
        @approved_loan.applied_by = @manager
        @approved_loan.should be_valid
      end
    end
  end

  describe "validations" do
    describe "validated_on and _by" do
      before :each do
        @loan = Factory.build(:disbursed_loan)
        @loan.should be_valid
        @loan.validated_on = @loan.disbursal_date
        @loan.validated_by = @manager
      end
      
      it "should be valid when validate properly" do
        @loan.should be_valid
      end
      it "should not be valid without validation date" do
        @loan.validated_on = nil
        @loan.should_not be_valid
      end
      it "should not be valid without validated_by" do
        @loan.validated_by = nil
        @loan.should_not be_valid
      end
    end

    describe "rejection" do
      before :each do
        @loan = Factory.build(:rejected_loan)
        @date = Date.new(2000,2,3)
      end
      it "should be valid when rejected properly" do
        @loan.should be_valid
      end
      it "should not be valid without a rejected_on date" do
        @loan.rejected_on = nil
        @loan.should_not be_valid
      end
      it "should not be valid without rejected_by" do
        @loan.rejected_by = nil
        @loan.should_not be_valid
      end
    end

    describe "client" do
      before :all do
        @loan = Factory.build(:loan)
      end
      it "should not be valid without belonging to a client" do
        @loan.client = nil
        @loan.should_not be_valid
      end
    end

    describe "amount" do
      it "should not be valid with nil amount" do
        @loan.amount_applied_for = nil
        @loan.amount = nil
        @loan.should_not be_valid
      end
      it "should not be valid with a negative amount" do
        @loan.amount = -1
        @loan.should_not be_valid
      end
      it "should not be valid with 0 amount" do
        @loan.amount = 0
        @loan.should_not be_valid
      end
    end
  
    describe "loan product attributes" do
      describe "if the loan product can give one" do
        it "should take the amount from the loan product" do
          @loan_product.max_amount = @loan_product.min_amount = 10000
          @loan.amount = nil
          @loan.should be_valid
          @loan.amount.should == 10000
        end
        
        it "should take the interest rate" do
          @loan_product.max_interest_rate = @loan_product.min_interest_rate = 20
          @loan.interest_rate = nil
          @loan.should be_valid
          @loan.interest_rate.should == 0.2
        end
      end
      
      describe "if the loan product cannot give one" do
        it "should not take the amount from the loan product" do
          @loan_product.max_amount = 1000; @loan_product.min_amount = 100
          @loan.amount = nil
          @loan.should_not be_valid
          @loan.amount.should == nil
        end
        
        it "should not take the interest rate" do
          @loan_product.max_interest_rate = 30; @loan_product.min_interest_rate = 20
          @loan.interest_rate = nil
          @loan.should_not be_valid
          @loan.interest_rate.should == nil
        end
      end
    end
    

    describe "interest rate" do
      it "should not be valid without a proper interest_rate" do
        @loan.interest_rate = nil
        @loan.should_not be_valid
      end
      it "should not have a negative interest rate" do
        @loan.interest_rate = -1
        @loan.should_not be_valid
      end
    end
    
    describe "installment frequency" do
      before :each do
        @loan = Factory.build(:loan)
      end
      it "should be valid with a proper installment_frequency" do
        @loan.should be_valid
        [:daily, :weekly, :biweekly, :monthly].each do |fq|
          @loan.installment_frequency = fq
          @loan.should be_valid
        end
      end
      
      it "should not be valid without proper installment_frequency" do
        @loan.should be_valid
        ['day',:month, :week, 'month',7,14,30].each do |fq|
          @loan.installment_frequency = fq
          @loan.should_not be_valid
        end
      end
    end
    describe "number of installments" do
      it "should not be valid without a proper number_of_installments" do
        @loan.number_of_installments = nil
        @loan.should_not be_valid
      end
      it "should not have negatove number of installments" do
        @loan.number_of_installments = -1
        @loan.should_not be_valid
      end
      it "should not have zero installments" do
        @loan.number_of_installments = -0
        @loan.should_not be_valid
      end
    end
  end

  describe "dates" do
    before :each do
      @loan = Factory.build(:approved_loan, :loan_product => @loan_product)
    end

    it "should not be valid without a scheduled_first_payment_date" do
      @loan.scheduled_first_payment_date = nil
      @loan.should_not be_valid
    end

    it "should not be valid without a scheduled_disbursal_date" do
      @loan.scheduled_disbursal_date = nil
      @loan.should_not be_valid
    end

    it "should not be valid with a disbursal date earlier than the loan is approved" do
      @loan.disbursed_by = @manager
      @loan.disbursal_date = @loan.approved_on - 10
      @loan.should_not be_valid
      @loan.disbursal_date = @loan.approved_on
      
      @loan.should be_valid
      @loan.disbursal_date = @loan.approved_on + 10
      @loan.should be_valid
    end

    it "should not be valid when validated_on is earlier than the disbursal_date" do
      @loan.disbursed_by   = @manager
      @loan.disbursal_date = @loan.scheduled_disbursal_date
      @loan.validated_on   = @loan.disbursal_date
      @loan.validated_by   = @manager
      @loan.should be_valid
      @loan.validated_on   = @loan.disbursal_date + 1
      @loan.should be_valid
      @loan.validated_on   = @loan.disbursal_date - 1
      @loan.should_not be_valid
    end
    
    it "should not be valid when written_off_on is earlier than the disbursal_date" do
      @loan.written_off_by = @manager
      @loan.disbursed_by   = @manager
      @loan.disbursal_date = @loan.scheduled_disbursal_date
      @loan.written_off_on = @loan.disbursal_date
      @loan.should be_valid
      @loan.written_off_on = @loan.disbursal_date + 1
      @loan.should be_valid
      @loan.written_off_on = @loan.disbursal_date - 1
      @loan.should_not be_valid
    end
    
    it "should not be valid without approved_on earlier than scheduled_disbursal_date" do
      @loan.scheduled_disbursal_date = @loan.approved_on - 10
      @loan.should_not be_valid
      @loan.scheduled_disbursal_date = @loan.approved_on
      @loan.should be_valid
      @loan.scheduled_disbursal_date = @loan.approved_on + 10
      @loan.should be_valid
    end
    
    it "should not be valid without being properly written off" do
      @loan.disbursal_date = @loan.scheduled_disbursal_date
      @loan.disbursed_by   = @manager
      @loan.written_off_on = @loan.disbursal_date
      @loan.written_off_by = @manager
      @loan.should be_valid
      @loan.written_off_on = @loan.disbursal_date
      @loan.written_off_by = nil
      @loan.should_not be_valid
      @loan.written_off_on = nil
      @loan.written_off_by = @manager
      @loan.should_not be_valid
    end
    
    it "should not be valid without being properly disbursed" do
      @loan.disbursal_date = @loan.scheduled_disbursal_date
      @loan.disbursed_by   = @manager
      @loan.should be_valid
      @loan.disbursal_date = nil
      @loan.disbursed_by   = @manager
      @loan.should_not be_valid
      @loan.disbursal_date = @loan.scheduled_disbursal_date
      @loan.disbursed_by   = nil
      @loan.should_not be_valid
    end
    
    it "should not be valid when scheduled_first_payment_date is before scheduled_disbursal_date" do
      @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date + 1
      @loan.should be_valid
      @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date
      @loan.should be_valid
      @loan.scheduled_first_payment_date = @loan.scheduled_disbursal_date - 1  # before disbursed
      @loan.should_not be_valid
    end
  end
  
  describe "center" do
    before :all do
      @loan = Factory.build(:loan, :client => @client, :center => nil)
      @loan.save
    end
    
    it "should have a center" do
      @loan.center.should == @center
    end

    it "should not change the center when the client center changes" do
      @center = @client.center[0]
      @center2 = Factory(:center)
      @client.center = @center2
      @loan.valid?
      @loan.center.should == @center
    end
  end

  describe "approved loan" do
    before :each do
      @approved_loan = Factory.build(:approved_loan)
    end
    it "should have status approved" do
      @approved_loan.status.should == :approved
    end
    it "should disburse properly" do
      @approved_loan.disbursal_date = @approved_loan.scheduled_disbursal_date
      @approved_loan.disbursed_by   = @manager
      @approved_loan.save
      @approved_loan.status.should == :outstanding
    end
  end

  describe "disbursed loan" do
    before :each do
      @disbursed_loan = Factory.build(:disbursed_loan, :loan_product => @loan_product)
      @disbursed_loan.save
    end

    it "should have status :outstanding" do
      @disbursed_loan.status.should == :outstanding
    end

    it "should make a sane payment schedule" do
      (@disbursed_loan.scheduled_first_payment_date + (@disbursed_loan.number_of_installments - 1) * 7).should == @disbursed_loan.payment_schedule.keys.max
    end

    it ".scheduled_repaid_on give the proper date" do
      @disbursed_loan.scheduled_repaid_on.should eql(Date.parse('2001-05-23'))
    end

    it "should have proper values for principal, interest and total to be received" do
      @disbursed_loan.total_interest_to_be_received.should == 1000 * 0.2
      @disbursed_loan.total_to_be_received.should == 1000 * (1.2)
    end

    it "should writeoff properly" do
      @disbursed_loan.written_off_on = @disbursed_loan.scheduled_first_payment_date
      @disbursed_loan.written_off_by = @manager
      @disbursed_loan.status.should == :written_off
      @disbursed_loan.status(@loan.scheduled_first_payment_date - 1).should == :outstanding
    end

    it "should not repay unsaved loan" do
      lambda{@disbursed_loan.repay(@loan.total_to_be_received, @user, Date.today, @manager)}.should raise_error
    end
    
    it "should be repaid when repaid" do
      @disbursed_loan2 = Factory.build(:disbursed_loan, :loan_product => @loan_product)
      @disbursed_loan2.save
      @disbursed_loan2.id.should_not be_nil
      @disbursed_loan2.history_disabled=false
      @disbursed_loan2.update_history
      
      r = @disbursed_loan2.repay(@disbursed_loan2.total_to_be_received, @user, Date.today, @manager)
      r[:status].should == true
      @disbursed_loan2.status.should == :repaid
      @disbursed_loan2.status(@disbursed_loan2.scheduled_disbursal_date - 1).should == :approved
    end
    
    it ".status should give status accoring to changing properties before being approved" do
      @disbursed_loan.status(@disbursed_loan.applied_on - 1).should == :applied_in_future
      @disbursed_loan.status(@disbursed_loan.applied_on).should == :applied
      @disbursed_loan.status(@disbursed_loan.approved_on - 1).should == :applied
      @disbursed_loan.status.should == :outstanding
    end
  end # disbursed loan



  describe "installment_dates" do
    before :each do
      @loan = Factory.build(:approved_loan, :loan_product => @loan_product)
      @loan.save
      @dates = @loan.installment_dates
    end

    it "should give a list with correct dates" do
      @dates.uniq.size.should eql(@loan.actual_number_of_installments)
      @dates.sort[0].should eql(@loan.scheduled_first_payment_date)
      @dates.sort[-1].should eql(@loan.scheduled_repaid_on)
    end

    it ".installment_dates should correctly deal with holidays" do
      Holiday.all.destroy!; HolidayCalendar.all.destroy!
      d1 = @loan.installment_dates[5].dup.freeze
      _D = @loan.installment_dates[5].dup
      @h = Holiday.new(:name => "test", :date => _D, :new_date => _D + 2)
      @h.save
      @hc = HolidayCalendar.new(:branch_id => @loan.center.branch.id)
      @hc.add_holiday(@h)
      @hc.save
      @loan.update_history
      @loan.clear_cache
      @loan.installment_dates[5].should == (d1 + 2)
      HolidayCalendar.all.destroy!
      Holiday.all.destroy!
    end
    
  end

  describe "schedules" do
    before :all do
      @disbursed_loan = Factory.build(:disbursed_loan, :loan_product => @loan_product)
      @disbursed_loan.save
    end

    it ".payment_schedule should give correct results" do
      @disbursed_loan.payment_schedule.keys.sort.each_with_index do |k,i|
        case i
        when 0
          k.should == @disbursed_loan.scheduled_disbursal_date
        when 1
          k.should == @disbursed_loan.scheduled_first_payment_date 
        else
          k.should == @disbursed_loan.scheduled_first_payment_date + (7*(i-1))
        end
        ps = @disbursed_loan.payment_schedule[k]
        ps[:total_principal].should == 40 * (i)
        ps[:total_interest].should == (200/25) * i
      end
    end
    
    it ".payments_hash should give correct results" do
      @disbursed_loan.history_disabled=false
      @disbursed_loan.save
      @disbursed_loan.payments_hash.should_not be_blank
      @disbursed_loan.disbursal_date = @disbursed_loan.scheduled_disbursal_date
      @disbursed_loan.disbursed_by = @manager
      @disbursed_loan.clear_cache
      @disbursed_loan.save
      # @disbursed_loan.id = nil
      @disbursed_loan = Loan.get(@disbursed_loan.id)
      7.times do |i|
        status = @disbursed_loan.repay(48, @user, @disbursed_loan.scheduled_first_payment_date + (7*i), @manager)
        status[:status].should be_true      
      end
      @disbursed_loan.update_history
      @disbursed_loan.payments_hash.keys.sort.each_with_index do |k,i|
        case i
        when 0
          k.should == @disbursed_loan.scheduled_disbursal_date
        else
          k.should == @disbursed_loan.scheduled_first_payment_date + (7*(i-1))
        end
        if i >= 3
          ps = @disbursed_loan.payments_hash[k]
          ps[:total_principal].to_i.should == 40 * (i) unless i > 7
          ps[:total_interest].should == (200/25) * (i) unless i > 7
        end
      end
    end
  end
    
  describe "loan history" do
    describe "normal operation" do
      before :all do
        Payment.all.destroy!
        LoanHistory.all.destroy!
        @center2 = Factory.create(:center, :manager => @manager, :branch => @branch, :meeting_day => (Date.today + 10).weekday, :creation_date => Date.new(1999,12,31))
        @center2.save
        @client2 = Factory.create(:client, :center => @center2, :created_by_user_id => @user.id)
        @loan2 = Factory.build(:disbursed_loan, :client => @client2, :repayment_style => @flat, :history_disabled => false)
        @loan2.save
        7.times do |i|
          p = @loan2.repay(48, @user, @loan2.scheduled_first_payment_date + (7*i), @manager)
          p[:status].should be_true
        end
      end
      
      it "should be correctly calculated" do
        @loan2.clear_cache
        hist = @loan2.calculate_history
        os_prin = 1000
        os_tot = 1200
        hist.each_with_index do |h,i|
          h[:scheduled_outstanding_principal].should == 1000 - (40*([0,i-2].max))
          h[:scheduled_outstanding_total].should == 1200 -(48 * ([0,i-2].max))
          h[:status].should == STATUSES.index(:disbursed) + 1 if i == 2
          if i > 2
            if i < 10
              h[:principal_due].should == 0
              h[:interest_due].should == 0
              h[:principal_paid].should == 40
              h[:interest_paid].should == 8
              h[:actual_outstanding_principal].should == 1000 -(40 * ([0,i-2].max)) 
            else
              h[:principal_due].should == (i - 9) * 40
              h[:interest_due].should == (i - 9) * 8
              h[:principal_paid].should == 0
              h[:interest_paid].should == 0
              h[:actual_outstanding_principal].should == 1000 -(40 * 7) 
              #if h[:date] > @loan2.scheduled_first_payment_date + (7 * 6)
              #  h[:days_overdue].should ==  (h[:date] - @loan2.scheduled_first_payment_date - 42).to_i
              #end
            end
          end
        end
      end
      
      describe "database" do
        it "should have correct values" do
          repository.adapter.query("SELECT SUM(principal_paid) from loan_history")[0].should == 280
        end
        it "should have correct number of rows" do
          repository.adapter.query("SELECT COUNT(*) from loan_history")[0].should == @loan.number_of_installments + 3
        end
      end
    end

    describe "advances" do
      before :all do
        Payment.all.destroy!
        LoanHistory.all.destroy!
        @loan = Factory.build(:disbursed_loan)
        @loan.save
        @loan.repay(100, @user, @loan.scheduled_first_payment_date, @center.manager)
      end
      
      it "should show correct advance figure" do
        lh = @loan.loan_history.find{|lh| lh.date == @loan.scheduled_first_payment_date}
        lh.advance_principal_paid_today.should == 52
      end

      it "should show correct advance adjusted figure" do
        lh = @loan.loan_history.find{|lh| lh.date == @loan.scheduled_first_payment_date + 7}
        lh.advance_principal_adjusted_today.should == 40
      end

    end
  end
    
    
  it "should not be deleteable if verified" do
    @loan.verified_by = User.first
    @loan.save
    @loan.destroy.should be_false

    @loan.verified_by = nil
    @loan.destroy.should be_true
  end
    

  it "should give correct cashflow for irr" do
  end

  it "should takeover properly" do
    @loan2 = Object.const_get("#{@loan.discriminator}").new
    @loan2.attributes = @loan.attributes
    @loan_product.min_interest_rate = 0
    @loan_product.min_amount = 0
    @loan_product.save
    @loan2.loan_product = @loan_product
    @loan2.original_amount = @loan.amount
    @loan2.original_disbursal_date = @loan.scheduled_disbursal_date
    @loan2.original_first_payment_date = @loan.scheduled_first_payment_date
    @loan2.taken_over_on_installment_number = 10
    @loan2.valid?; @loan2.errors.each{|e| puts e}
    @loan2.should be_valid
#    @loan._show_cf; @loan2._show_cf
    @loan2.payment_schedule.count.should == @loan.payment_schedule.count - 9
    @loan2.taken_over_on = Date.parse("2001-02-04")
    @loan2.clear_cache
    @loan2.payment_schedule.count.should == @loan.payment_schedule.count - 9
  end

  it "should have correct takeover schedule and balances" do
  end

  it "should do deletion of payment" do 
  end

  
  describe "repayments" do
    before :all do
      Payment.all.destroy!
      Loan.all.destroy!
      LoanHistory.all.destroy!
      @center3 = Factory.create(:center, :manager => @manager, :branch => @branch, :meeting_day => :saturday, :creation_date => Date.new(1999,12,31))
      @center3.save
      @client3 = Factory.create(:client, :center => @center3, :created_by_user_id => @user.id)
      @loan3 = Factory.build(:disbursed_loan, :client => @client3, :repayment_style => @flat)
      @loan3.history_disabled = false
      @loan3.save
      fee =  Fee.create(:amount => 100, :name => "processing fee", :payable_on => :loan_disbursal_date)
      af = ApplicableFee.new(:applicable_id => @loan3.id, :applicable_type => 'Loan',
                           :applicable_on => @loan3.scheduled_disbursal_date, :fee => fee,
                           :amount => 100)
      af.should be_valid
      af.save.should be_true
      @loan3.disbursal_date = @loan3.scheduled_disbursal_date
      @loan3.disbursed_by = @manager
      @loan3.save
      @loan3.reload
    end
    it "should repay principal and interest properly" do
      r = @loan3.repay(500, @user, @loan3.scheduled_first_payment_date, @manager)
      r[:status].should == true
      r[:principal][0].type.should == :principal
      r[:principal].map(&:amount).sum.should == 492
      r[:interest][0].type.should == :interest
      r[:interest][0].amount.should == 8
    end
    describe "fees" do
      describe "get_fee_payments" do
        it "should give empty fees before applicable date" do
          ps = @loan3.get_fee_payments(100, @loan3.applied_on, nil, nil)
          ps.should == []
        end
        it "should give one fees on disbursal date and after" do
          ps = @loan3.get_fee_payments(200, @loan3.disbursal_date, nil, nil)
          ps[0].amount.should == 100
          ps[0].type.should == :fees
        end
      end

      it "should pay_fees properly" do
        result = @loan3.pay_fees(100, @loan3.disbursal_date, @manager, @user)
        result[:status].should == true
        result[:fees][0].errors.should be_blank
      end

    end

    describe "pay_normal, prorata, etc" do
      before :each do
        #@loan3 = Factory.build(:disbursed_loan)
        #@loan3.save.should == true
      end
      
      describe "normal payment split" do
        it "should make a correct split when paid properly" do
          r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager)
          r[:principal] = r[:principal].map{|p| [p.received_for, p]}.to_hash
          r[:interest]  = r[:interest].map{|p| [p.received_for, p]}.to_hash
          r[:status].should == true
          r[:principal][@loan.scheduled_first_payment_date].amount.should == 40
          r[:interest][@loan.scheduled_first_payment_date].amount.should == 8
        end
        describe "second payment" do
          before :all do
            r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager)
            @loan3.reload
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager)
            @r[:principal] = @r[:principal].map{|p| [p.received_for, p]}.to_hash
            @r[:interest]  = @r[:interest].map{|p| [p.received_for, p]}.to_hash
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal].size.should == 1
            @r[:principal].first[1].amount.should == 40
          end
          it "should split interest propery" do
            @r[:interest].size.should == 1
            @r[:interest].first[1].amount.should == 8
          end
        end
        describe "delayed payment" do
          before :all do
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager)
            @r[:principal] = @r[:principal].map{|r| [r.received_for, r]}.to_hash
            @r[:interest]  = @r[:interest].map{|r| [r.received_for, r]}.to_hash
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][@loan.scheduled_first_payment_date].amount.should == 32
            @r[:principal][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:principal][@loan.scheduled_first_payment_date].timeliness.should == "overdue"
            @r[:principal][@loan.scheduled_first_payment_date + 7].should be_nil
          end
          it "should split interest propery" do
            @r[:interest][@loan.scheduled_first_payment_date].amount.should == 8
            @r[:interest][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:interest][@loan.scheduled_first_payment_date].timeliness.should == "overdue"
            @r[:interest][@loan.scheduled_first_payment_date + 7].amount.should == 8
            @r[:interest][@loan.scheduled_first_payment_date + 7].received_for.should == @loan.scheduled_first_payment_date + 7
            @r[:interest][@loan.scheduled_first_payment_date + 7].timeliness.should == "normal"
          end
        end
        describe "under payment" do
          before :all do
            @r = @loan3.repay(40, @user, @loan.scheduled_first_payment_date, @manager)
            @r[:principal] = @r[:principal].map{|p| [p.received_for, p]}.to_hash
            @r[:interest]  = @r[:interest].map{|p| [p.received_for, p]}.to_hash
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][@loan.scheduled_first_payment_date].amount.should == 32
            @r[:principal][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:principal][@loan.scheduled_first_payment_date].timeliness.should == "normal"
          end
          it "should split interest propery" do
            @r[:interest][@loan.scheduled_first_payment_date].amount.should == 8
            @r[:interest][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:interest][@loan.scheduled_first_payment_date].timeliness.should == "normal"
          end
        end
        describe "over payment" do
          before :all do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager)
            @r[:principal] = @r[:principal].map{|p| [p.received_for, p]}.to_hash
            @r[:interest]  = @r[:interest].map{|p| [p.received_for, p]}.to_hash
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][@loan.scheduled_first_payment_date].amount.should == 40
            @r[:principal][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:principal][@loan.scheduled_first_payment_date].timeliness.should == "normal"
            @r[:principal][@loan.scheduled_first_payment_date + 7].amount.should == 7
            @r[:principal][@loan.scheduled_first_payment_date + 7].received_for.should == @loan.scheduled_first_payment_date + 7
            @r[:principal][@loan.scheduled_first_payment_date + 7].timeliness.should == "advance"
          end
          it "should split interest propery" do
            @r[:interest][@loan.scheduled_first_payment_date].amount.should == 8
            @r[:interest][@loan.scheduled_first_payment_date].received_for.should == @loan.scheduled_first_payment_date
            @r[:interest][@loan.scheduled_first_payment_date].timeliness.should == "normal"
          end
        end
        describe "all together" do
          it "start with an overpayment" do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager)
            @r[:principal].map(&:amount).sum.should == 47
            @r[:interest].map(&:amount).sum.should == 8
            @r = @loan3.repay(20, @user, @loan.scheduled_first_payment_date + 7, @manager)
            @r[:principal].map(&:amount).sum.should == 12
            @r[:interest].map(&:amount).sum.should == 8
            @r = @loan3.repay(10, @user, @loan.scheduled_first_payment_date + 21, @manager)
            @r[:principal].should == []            # no principal paid
            @r[:interest].map(&:amount).sum.should == 10
            @r = @loan3.repay(155, @user, @loan.scheduled_first_payment_date + 28, @manager)
            @r[:principal].map(&:amount).sum.should == 141
            @r[:interest].map(&:amount).sum.should == 14
          end
        end

      end

      describe "prorata payment split" do
        before :all do
          @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager, false, :prorata)
        end
        it "should split properly when paid normally" do
          @r[:status].should == true
          @r[:principal].first.amount.should == 40
          @r[:interest].first.amount.should == 8
        end
        describe "second payment" do
          before :all do
            r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager, false, :prorata)
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :prorata)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][0].amount.should == 40
          end
          it "should split interest propery" do
            @r[:interest][0].amount.should == 8
          end
        end
        describe "delayed payment" do
          before :all do
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :prorata)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][0].amount.should == 40
          end
          it "should split interest propery" do
            @r[:interest][0].amount.should == 8
          end
        end
        describe "under payment" do
          before :all do
            @loan3.reload
            @r = @loan3.repay(40, @user, @loan.scheduled_first_payment_date, @manager, false, :prorata)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][0].amount.should == (40 * 40/48.0).round(2)
          end
          it "should split interest propery" do
            @r[:interest][0].amount.should == (40 * 8 / 48.0).round(2)
          end
        end
        describe "over payment" do
          before :all do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager, false, :prorata)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal][0].amount.should == 40
            debugger
            @r[:principal][1].amount.should == (7 * 40 / 48.to_f).round(2)
          end
          it "should split interest propery" do
            @r[:interest][0].amount.should == 8
            @r[:interest][1].amount.should == (7 * 8 / 48.to_f).round(2)
          end
        end
        describe "all together" do
          it "start with an overpayment" do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager, false, :prorata)
            @r[:principal].map(&:amount).sum.should == (55 * 40/48.0).round(2)
            @r[:interest].map(&:amount).sum.should == (55 * 8/48.0).round(2)
            @loan3.reload
            @r = @loan3.repay(20, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :prorata)
            @r[:principal].map(&:amount).sum.should == (20 * 40/48.0).round(2)
            @r[:interest].map(&:amount).sum.should == (20 * 8/48.0).round(2)
            @loan3.reload
            @r = @loan3.repay(10, @user, @loan.scheduled_first_payment_date + 21, @manager, false, :prorata)
            @r[:principal].map(&:amount).sum.should == (10 * 40/48.0).round(2)
            @r[:interest].map(&:amount).sum.should == (10 * 8/48.0).round(2)
            @loan3.reload
            @r = @loan3.repay(155, @user, @loan.scheduled_first_payment_date + 28, @manager, false, :prorata)
            @r[:principal].map(&:amount).sum.round(2).should == (155 * 40/48.0).round(2)
            @r[:interest].map(&:amount).sum.round(2).should == (155 * 8/48.0).round(2)
          end
        end

      end
      describe "sequential payment split" do
        it "should make a correct split when paid properly" do
          r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager, false, :sequential)
          r[:status].should == true
          r[:principal].map(&:amount).sum.should == 40
          r[:interest].map(&:amount).sum.should == 8
        end
        describe "second payment" do
          before :all do
            r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date, @manager, false, :sequential)
            @loan3.reload
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :sequential)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal].map(&:amount).sum.should == 40
          end
          it "should split interest propery" do
            @r[:interest].map(&:amount).sum.should == 8
          end
        end
        describe "delayed payment" do
          before :all do
            @r = @loan3.repay(48, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :sequential)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal].map(&:amount).sum.should == 40
          end
          it "should split interest propery" do
            @r[:interest].map(&:amount).sum.should == 8
          end
        end
        describe "under payment" do
          before :all do
            @r = @loan3.repay(40, @user, @loan.scheduled_first_payment_date, @manager, false, :sequential)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal].map(&:amount).sum.should == 32
          end
          it "should split interest propery" do
            @r[:interest].map(&:amount).sum.should == 8
          end
        end
        describe "over payment" do
          before :all do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager, false, :sequential)
          end
          it "should make the second payment also properly" do
            @r[:status].should == true
          end
          it "should split principal properly" do
            @r[:principal].map(&:amount).sum.should == 40
          end
          it "should split interest propery" do
            @r[:interest].map(&:amount).sum.should == 15
          end
        end
        describe "all together" do
          it "start with an overpayment" do
            @r = @loan3.repay(55, @user, @loan.scheduled_first_payment_date, @manager, false, :sequential)
            @r[:principal].map(&:amount).sum.should == 40
            @r[:interest].map(&:amount).sum.should == 15
            @loan3.reload
            @r = @loan3.repay(20, @user, @loan.scheduled_first_payment_date + 7, @manager, false, :sequential)
            @r[:principal].map(&:amount).sum.should == 19
            @r[:interest].map(&:amount).sum.should == 1
            @loan3.reload
            @r = @loan3.repay(10, @user, @loan.scheduled_first_payment_date + 21, @manager, false, :sequential)
            @r[:principal].map(&:amount).sum.should == 10
            @r[2].should == nil 
            @loan3.reload
            @r = @loan3.repay(155, @user, @loan.scheduled_first_payment_date + 28, @manager, false, :sequential)
            @r[:principal].map(&:amount).sum.round(2).should == 131
            @r[:interest].map(&:amount).sum.should == 24
          end
        end

      end

    end
  end


  describe "hookable validations" do
    before :all do
      @loan = Factory.build(:approved_loan)
      @loan.save
    end
    it "should not be valid if duplicated" do
      @loan_product.loan_validation_methods = "loans_must_not_be_duplicated"
      @loan_product.save
      @loan2 = Loan.new(@loan.attributes.except(:id).merge(:loan_product => @loan_product))
      @loan2.should_not be_valid
    end


    describe "scheduled dates" do
      before :each do
      end
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

    describe "check_payment_of_fees_before_disbursal" do
      it "should not disburse if loan fees are not paid" do
        #when fees are not paid
        ApplicableFee.all.destroy!
        @loan_product.loan_validation_methods = "check_payment_of_fees_before_disbursal"
        fee =  Fee.create(:amount => 100, :name => "processing fee", :payable_on => :loan_disbursal_date)
        @loan_product.fees << fee
        @loan_product.save
        @loan = Loan.new(:amount => 1000, :interest_rate => 0.2, :installment_frequency => :weekly, :number_of_installments => 25, :scheduled_first_payment_date => "2000-12-06", :applied_on => "2000-02-01", :scheduled_disbursal_date => "2000-06-14", :applied_by => @manager, :client => Client.get(@client.id), :funding_line => @funding_line, :loan_product => @loan_product, :approved_by => @manager, :approved_on => "2000-02-03")
        @loan.save.should be_true
        @loan.disbursal_date = @loan.scheduled_disbursal_date
        @loan.disbursed_by = @manager
        @loan.save.should be_false
        
        #when fees are paid
        result = @loan.pay_fees((@loan.fees[:status].amount || 0), @loan.fee_schedule.keys.first, @manager, User.first)
        @loan.disbursal_date = @loan.scheduled_disbursal_date
        @loan.disbursed_by = @manager
        @loan.save.should be_true
      end
    end
    
  end
end
