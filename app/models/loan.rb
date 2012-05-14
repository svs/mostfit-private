class Loan
  include DataMapper::Resource
  include FeesContainer
  # include Identified
  # include Pdf::LoanSchedule if PDF_WRITER
  include ExcelFormula
  include LoanDisplay
  include LoanFiddling
  DAYS = [:none, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  before :valid?,    :parse_dates
  before :valid?,    :convert_blank_to_nil
  before :valid?,    :set_center
  before :valid?,    :set_loan_product_parameters

  after  :create,    :levy_fees_new          # we need a separate one for create for a variety of reasons to  do with overwriting old fees
  after  :create,    :update_cycle_number

  before :save,      :levy_fees
  before :save,      :set_bullet_installments
  after  :save,      :update_history_caller  # also seems to do updates

  before :destroy,   :verified_cannot_be_deleted


  # This could really use a better name.
  def rs
    self.repayment_style or self.loan_product.repayment_style
  end

  def set_bullet_installments
    number_of_installments = 1 if rs.style == "BulletLoan"
  end


  #  after  :destroy, :update_history

  before :valid?, :set_amount

  validates_with_method :original_properties_specified?, :when => Proc.new{|l| l.taken_over?}
  validates_with_method :taken_over_properly?, :when => Proc.new{|l| l.taken_over?}

  attr_accessor :history_disabled  # set to true to disable history writing by this object
  attr_accessor :interest_percentage
  attr_accessor :already_updated
  attr_accessor :orig_attrs
  attr_accessor :loan_extended          # set to true if you have mixed in the appropriate loan repayment functions

  property :id,                             Serial
  property :discriminator,                  Discriminator, :nullable => false, :index => true

  property :amount,                         Float, :nullable => false, :index => true, :min => 0.01  # this is the disbursed amount
  property :amount_applied_for,             Float, :index => true
  property :amount_sanctioned,              Float, :index => true

  property :interest_rate,                  Float, :nullable => false, :index => true
  property :installment_frequency,          Enum.send('[]', *INSTALLMENT_FREQUENCIES), :nullable => false, :index => true
  property :number_of_installments,         Integer, :nullable => false, :index => true
  property :weekly_off,                     Integer, :nullable => true # cwday pls
  property :client_id,                      Integer, :nullable => false, :index => true

  property :scheduled_disbursal_date,       Date, :nullable => false, :auto_validation => false, :index => true
  property :scheduled_first_payment_date,   Date, :nullable => false, :auto_validation => false, :index => true
  property :applied_on,                     Date, :nullable => false, :auto_validation => false, :index => true, :default => Date.today
  property :approved_on,                    Date, :auto_validation => false, :index => true
  property :rejected_on,                    Date, :auto_validation => false, :index => true
  property :disbursal_date,                 Date, :auto_validation => false, :index => true
  property :written_off_on,                 Date, :auto_validation => false, :index => true
  property :suggested_written_off_on,       Date, :auto_validation => false, :index => true
  property :write_off_rejected_on,          Date, :auto_validation => false, :index => true
  property :validated_on,                   Date, :auto_validation => false, :index => true
  property :preclosed_on,                   Date, :auto_validation => false, :index => true
  
  property :validation_comment,             Text
  property :created_at,                     DateTime, :index => true, :default => Time.now
  property :updated_at,                     DateTime, :index => true
  property :deleted_at,                     ParanoidDateTime
  property :loan_product_id,                Integer,  :index => true

  property :applied_by_staff_id,               Integer, :nullable => true, :index => true
  property :approved_by_staff_id,              Integer, :nullable => true, :index => true
  property :rejected_by_staff_id,              Integer, :nullable => true, :index => true
  property :disbursed_by_staff_id,             Integer, :nullable => true, :index => true
  property :written_off_by_staff_id,           Integer, :nullable => true, :index => true
  property :preclosed_by_staff_id,             Integer, :nullable => true, :index => true
  property :suggested_written_off_by_staff_id, Integer, :nullable => true, :index => true
  property :write_off_rejected_by_staff_id,    Integer, :nullable => true, :index => true
  property :validated_by_staff_id,             Integer, :nullable => true, :index => true
  property :verified_by_user_id,               Integer, :nullable => true, :index => true
  property :created_by_user_id,                Integer, :nullable => true, :index => true
  property :cheque_number,                     String,  :length => 20, :nullable => true, :index => true
  property :cycle_number,                      Integer, :default => 1, :nullable => false, :index => true
  property :loan_pool_id,                      Integer, :nullable => true, :index => true

  #these amount and disbursal dates are required for TakeOver loan types. 
  property :original_amount,                    Integer
  property :original_disbursal_date,            Date
  property :original_first_payment_date,        Date
  property :taken_over_on,                      Date
  property :taken_over_on_installment_number,   Integer

  property :loan_utilization_id,                Integer, :lazy => true, :nullable => true
  property :under_claim_settlement,             Date, :nullable => true
  property :repayment_style_id,                 Integer, :nullable => true

  # property :center_id, Integer                 #temporary, while we fix the loan_center_memberships
  

  # associations
  belongs_to :client
  belongs_to :funding_line,              :nullable => true
  belongs_to :loan_product
  belongs_to :loan_purpose,              :nullable  => true
  belongs_to :occupation,                :nullable => true
  belongs_to :applied_by,                :child_key => [:applied_by_staff_id],                :model => 'StaffMember'
  belongs_to :approved_by,               :child_key => [:approved_by_staff_id],               :model => 'StaffMember'
  belongs_to :rejected_by,               :child_key => [:rejected_by_staff_id],               :model => 'StaffMember'
  belongs_to :disbursed_by,              :child_key => [:disbursed_by_staff_id],              :model => 'StaffMember'
  belongs_to :written_off_by,            :child_key => [:written_off_by_staff_id],            :model => 'StaffMember'
  belongs_to :preclosed_by,              :child_key => [:preclosed_by_staff_id],            :model => 'StaffMember'
  belongs_to :suggested_written_off_by,  :child_key => [:suggested_written_off_by_staff_id],  :model => 'StaffMember'
  belongs_to :write_off_rejected_by,     :child_key => [:write_off_rejected_by_staff_id],     :model => 'StaffMember' 
  belongs_to :validated_by,              :child_key => [:validated_by_staff_id],              :model => 'StaffMember'
  belongs_to :created_by,                :child_key => [:created_by_user_id],                 :model => 'User'
  belongs_to :loan_utilization
  belongs_to :verified_by,               :child_key => [:verified_by_user_id],                :model => 'User'
  belongs_to :repayment_style


  has n, :loan_history,                                                                       :model => 'LoanHistory'
  has n, :payments
  has n, :audit_trails,       :child_key => [:auditable_id], :auditable_type => "Loan"
  has n, :portfolio_loans
  has 1, :insurance_policy
  has n, :applicable_fees,    :child_key => [:applicable_id], :applicable_type => "Loan"

  has n, :loan_center_memberships, :child_key => [:member_id]

  #validations
  validates_present      :client, :scheduled_disbursal_date, :scheduled_first_payment_date, :applied_by, :applied_on
  validates_with_method  :amount,                       :method => :amount_greater_than_zero?
  validates_with_method  :interest_rate,                :method => :interest_rate_greater_than_or_equal_to_zero?
  validates_with_method  :number_of_installments,       :method => :number_of_installments_greater_than_zero?
  validates_with_method  :applied_on,                   :method => :applied_before_appoved?
  validates_with_method  :approved_on,                  :method => :applied_before_appoved?
  validates_with_method  :applied_on,                   :method => :applied_before_rejected?
  validates_with_method  :rejected_on,                  :method => :applied_before_rejected?
  validates_with_method  :approved_on,                  :method => :approved_before_disbursed?
  validates_with_method  :disbursal_date,               :method => :approved_before_disbursed?
  validates_with_method  :disbursal_date,               :method => :disbursed_before_written_off?
  validates_with_method  :written_off_on,               :method => :disbursed_before_written_off?
  validates_with_method  :suggested_written_off_on,     :method => :disbursed_before_suggested_written_off?
  validates_with_method  :write_off_rejected_on,        :method => :disbursed_before_write_off_rejected?
  validates_with_method  :write_off_rejected_on,        :method => :rejected_before_suggested_write_off?
  validates_with_method  :disbursal_date,               :method => :disbursed_before_validated?
  validates_with_method  :validated_on,                 :method => :disbursed_before_validated?
  validates_with_method  :approved_on,                  :method => :applied_before_scheduled_to_be_disbursed?
  validates_with_method  :scheduled_disbursal_date,     :method => :applied_before_scheduled_to_be_disbursed?
  validates_with_method  :approved_on,                  :method => :properly_approved?
  validates_with_method  :approved_by,                  :method => :properly_approved?
  validates_with_method  :rejected_on,                  :method => :properly_rejected?
  validates_with_method  :rejected_by,                  :method => :properly_rejected?
  validates_with_method  :written_off_on,               :method => :properly_written_off?
  validates_with_method  :suggested_written_off_on,     :method => :properly_suggested_for_written_off?
  validates_with_method  :write_off_rejected_on,        :method => :properly_write_off_rejected?
  validates_with_method  :written_off_by,               :method => :properly_written_off?
  validates_with_method  :suggested_written_off_by,     :method => :properly_suggested_for_written_off?
  validates_with_method  :write_off_rejected_by,        :method => :properly_write_off_rejected?
  validates_with_method  :disbursal_date,               :method => :properly_disbursed?
  validates_with_method  :disbursed_by,                 :method => :properly_disbursed?
  validates_with_method  :validated_on,                 :method => :properly_validated?
  validates_with_method  :validated_by,                 :method => :properly_validated?
  validates_with_method  :scheduled_first_payment_date, :method => :scheduled_disbursal_before_scheduled_first_payment?
  validates_with_method  :scheduled_disbursal_date,     :method => :scheduled_disbursal_before_scheduled_first_payment?
  validates_with_method  :cheque_number,                :method => :check_validity_of_cheque_number
  validates_with_method  :client_active,                :method => :is_client_active
  validates_with_method  :verified_by_user_id,          :method => :verified_cannot_be_deleted, :if => Proc.new{|x| x.deleted_at != nil}

  #product validations

  validates_with_method  :amount,                       :method => :is_valid_loan_product_amount
  validates_with_method  :interest_rate,                :method => :is_valid_loan_product_interest_rate
  validates_with_method  :number_of_installments,       :method => :is_valid_loan_product_number_of_installments
  validates_with_method  :clients,                      :method => :check_client_sincerity
  validates_with_method  :insurance_policy,             :method => :check_insurance_policy    


  # Public: updates the center memberships
  # Loans do not belong to Centers directly but through Memberships. In this case, a LoanCenterMembership
  # We are recreating the normal dm setters and getters to deal with this so we can still say @loan.center = Center.last for example
  def center=(center)
    center, as_of = center.class == Array ? center : [center, self.applied_on]
    return unless center.class == Center # fail silently. the validation will catch the invalid loan
    cm = LoanCenterMembership.new(:from => as_of, :club => center, :member => self)
    @c = nil
    self.loan_center_memberships << cm
  end
  
  # Public: returns the center that a client is a member of on a particular Date
  #
  # as_of is a Date which defaults to today's date
  # returns an array of Centers, since the client can belong to multiple centers on a given day
  #
  # TODO this does too many wasteful lookups. we can optimise this
  def center(as_of = applied_on)
    as_of ||= applied_on
    @c ||= {}
    @c[as_of] ||= Center.get(LoanCenterMembership.as_of(as_of, loan_center_memberships))
  end



  def holidays
    return @holidays if @holidays
    @holidays = center.branch.holidays.map{|h| [h.date, h.new_date]}.to_hash
  end

  def amt_sanctioned
    amount_sanctioned || amount
  end

  def amt_applied_for
    amount_applied_for || amount
  end

  # returns the row from LoanHistory table pertaining to the date given
  def info(date = Date.today)
    LoanHistory.first(:loan_id => id, :date.lte => date, :order => [:date.desc], :limit => 1)
  end


  def is_valid_loan_product_amount; is_valid_loan_product(:amount); end
  def is_valid_loan_product_interest_rate; is_valid_loan_product(:interest_rate); end
  def is_valid_loan_product_number_of_installments; is_valid_loan_product(:number_of_installments); end

  def is_valid_loan_product(method)
    loan_attr    = self.send(method)
    return [false, "No #{method} specified"] if not loan_attr or loan_attr===""
    return [false, "No loan product chosen"] unless self.loan_product
    product = self.loan_product
    #Checking if the loan adheres to minimum and maximums of the loan product
    {:min => :minimum, :max => :maximum}.each{|k, v|
      product_attr = product.send("#{k}_#{method}")
      if method==:interest_rate
        product_attr = product_attr.to_f/100.round(6)
        loan_attr    = loan_attr.to_f.round(6)
      end

      if k==:min and loan_attr and product_attr and (product_attr - loan_attr > 0.000001)
        return [false, "#{v.to_s.capitalize} #{method.to_s.humanize} limit violated"]
      elsif k==:max and loan_attr and product_attr and  (loan_attr - product_attr > 0.000001)
       return  [false, "#{v.to_s.capitalize} #{method.to_s.humanize} limit violated"]
      end
    }
    #check if loan is follows the minimum discrete value for amount and interest
    if product.respond_to?("#{method}_multiple")
      product_attr = product.send("#{method}_multiple")
      loan_attr = loan_attr*100 if method==:interest_rate
      remainder = loan_attr.remainder(product_attr)
      remainder = remainder/100 if method==:interest_rate
      return  [false, "#{method.to_s.capitalize} should be in multiples of #{product_attr}"]  if not loan_attr or remainder > EPSILON
    end
    return true
  end




  def self.search(q, per_page)
    if /^\d+$/.match(q)
      all(:conditions => {:id => q}, :limit => per_page)
    end
  end

  # clears all cached values
  def clear_cache
    @payments_cache = @schedule = @history_array = @fee_schedule = @holidays = @_installment_dates = @statuses = @schedulr = nil
  end

  def interest_percentage  # code dup with the FundingLine
    return nil if interest_rate.blank?
    format("%.2f", interest_rate * 100)
  end
  def interest_percentage= (percentage)
    #self.interest_rate = percentage.to_f/100
  end

  def grt_date
    client.grt_pass_date
  end

  def self.installment_frequencies
    # Loan.properties[:installment_frequency].type.flag_map.values would give us a garbled order, so:
    INSTALLMENT_FREQUENCIES
  end


  # LOAN MANIPULATION FUNCTIONS

  # this is the method used for creating payments, not directly on the Payment class
  # for +input+ it allows either a "total" amount as Fixnum or a Hash with
  # of the format { :principal => 100.0, :interest => 20.0, :fees => 10.0 }

  def repay(input, user, received_on, received_by, defer_update = false, style = NORMAL_REPAYMENT_STYLE, context = :default, desktop_id = nil, origin = nil)
    # this is the way to repay loans, _not_ directly on the Payment model    
    pmts = get_payments(input, user, received_on, received_by, defer_update, style, context, desktop_id, origin)
    make_payments(pmts, context, defer_update)
  end

  # This method prepares (but does not save) new payments based on the input. The input format is either a hash
  # or a fixnum or float. The hash lets you separate what types of payments to make, e.g.:
  #
  #   # this would create three separate payments, one for each amount
  #   { :principal => 100.0, :interest => 20.0, :fees => 10.0 }
  #
  # If a fixnum/float is supplied instead separation of the payment types is handled by the style parameter. By
  # default the style parameter is set to :normal, the alternative styles being :prorata, :sequential and reallocate_normal.
  # This defers separation out to the pay_normal, pay_prorata, pay_sequential and pay_reallocate_normal methods
  # respectively. Each of which will return a hash in the format described above.
  #
  # user          represents the user registering the payment in the system
  # received_on   the date on which the payment was made
  # received_by   the staff_member who took in the payment
  #
  # Some more documentation here would not go amiss, as far as I can tell context and defer_update are never used?
  #
  # Note that the #extend_loan method below does literally that, it extends the Loan model with the relevant
  # RepaymentStyle module, determined by either the loan's own RepaymentStyle or the related LoanProduct's RepaymentStyle
  #
  def get_payments(input, user, received_on, received_by, defer_update = false, style = NORMAL_REPAYMENT_STYLE, context = :default, desktop_id = nil, origin = nil) 
    self.extend_loan
    # only possible if we get a hash or a single number.
    unless input.is_a? Fixnum or input.is_a? Float or input.is_a?(Hash)
      raise "the input argument of Loan#repay should be of class Fixnum or Hash"
    end
    raise "cannot repay a loan that has not been saved" if new?

    # if vals is a single number, then split it per the chosen style
    # else vals is like {:fees => <Payment>, :interest => <Payment>, :principal => <Payment>}
    payment_split = input.is_a?(Hash) ? input : self.send("split_#{style}",input, received_on) 
    payments = []
    default_attributes = {:loan => self, :created_by => user, :received_by => received_by, :received_on => received_on}
    # once we have the payment split, we go sequentially down the loan history and pay off interest from the interest portion and p from p
    loan_history.all(:order => [:date]).each do |lh|
      timeliness = (lh.date == received_on ? "normal" : (lh.date > received_on ? "advance" : "overdue"))
      [:interest, :principal].each do |type|
        amt_due_today = lh.send("#{type}_due_today".to_sym)
        if amt_due_today > 0 and payment_split[type] > 0
          amt = [payment_split[type], amt_due_today].min.round(2)
          payments << Payment.new(default_attributes.merge(:timeliness => timeliness, :amount => amt, :received_for => lh.date, :type => type))
          payment_split[type] -= amt
        end
      end
    end
    payments
    
  end

  # This method attempts to register the given payments. The input is assumed to be a collection of Payment objects.
  #
  # We return an array representing the status of the update, which contains the following elements:
  #
  # Boolean     true or false depending on whether the payments could be registered (saved)
  # Payment     the payment with type :principal
  # Payment     the payment with type :interest
  # Array       the collection of payments with type :fees
  #
  # If any of the payments fails to register the entire transaction is rolled back
  # 
  # defer_update refers to history logging, set to true for batch updates so not every call updates
  # the loan_history (persumably this is done manually after the batch update.)
  #
  def make_payments(payments, context = :default, defer_update = false)
    return {:status => false, :reason => "No payments given to make"} if payments.empty?
    Payment.transaction do |t|
      self.history_disabled=true
      n = DateTime.now
      payments.each{|p| p.override_create_observer = true; p.created_at = n}    
      if payments.collect{|payment| payment.save(context)}.include?(false)
        t.rollback
        return {:status => false, :reason => payments.map{|p| [p.id, p.errors]}.to_hash}
      end
    end
    unless defer_update #i.e. bulk updating loans
      self.history_disabled=false
      @already_updated=false
      # We're mapping twice here? Can we just map{ |p| installment_dates.include?(p.received_on) } ?
      self.reload if payments.map{|p| p.received_on}.map{|d| installment_dates.include?(d)}.include?(false)
      update_history(true)  # update the history if we saved a payment
    end
    return {
      :status => true, 
      :principal => payments.find_all{|p| p.type==:principal}, 
      :interest  => payments.find_all{|p| p.type==:interest},
      :fees      => payments.find_all{|p| p.type==:fees}
    }
  end

  # Public: Returns a given cash amount as split into pieces such that the total interest due and the total principal due are 
  # paid in proportion to their due amounts.
  # creates separate payments based on which due date the payment is actually for

  def split_prorata(total, received_on)
    return [] unless total > 0
    # we need to select from loan history until the row where the int_due + prin_due is greater than the total received
    r = loan_history.all(:order => [:date]).select{|lh| lh.interest_due + lh.principal_due >= total}[0]
    total_due = r.interest_due + r.principal_due
    {:interest => (total * r.interest_due/total_due.to_f).round(2), :principal => (total * r.principal_due/total_due.to_f).round(2)}
  end
                                               
  def split_sequential(total, received_on)
    int_due = prin_due = 0
    loan_history.all(:order => [:date]).each do |lh|
      next if lh.interest_due_today + lh.principal_due_today == 0
      int_due_today = [total, lh.interest_due_today].min.round(2)
      int_due  += int_due_today
      total -= int_due_today
      prin_due_today = [total, lh.principal_due_today].min.round(2)
      prin_due += prin_due_today
      total -= prin_due_today
      break if total == 0
    end
    {:interest => int_due, :principal => prin_due}

  end

  # This method separates a received payment into :interest en :pricipal portions.
  # First the interest is taken out of the amount and any remaining amount is paid
  # towards the principal. It makes separate payments on all dates that are required to make a note of overdues,
  # advances, preclosures, adjustments, etc.
  def split_normal(total, received_on)
    # first take the accumulated interest up to received_on date
    int_due   =  [total,info(received_on).interest_due].min.round(2)
    # rest goes to principal
    prin_due  =  (total - int_due).round(2)
    {:interest => int_due, :principal => prin_due}
  end
    
  #   i = info(received_on)
  #   int_to_pay = i[:interest_due]
  #   prin_to_pay = i[:principal_due]
  #   payments = []
  #   int_amount_remaining  = [int_to_pay, total].min
  #   prin_amount_remaining = [prin_to_pay, total - int_amount_remaining].min
  #   total_amount_remaining = total
  #   puts "--------------#{received_on}----#{total_amount_remaining}-=>--#{int_to_pay}+#{prin_to_pay}-----"
  #   # first pay all accrued interest upto received_on and then all principal due until received_on
  #   loan_history.all(:date.lte => received_on, :order => [:date]).each do |lh|
  #     puts "#{lh.date} : remaining => #{total_amount_remaining} p_due => #{lh.principal_due} i_due => #{lh.interest_due}"
  #     break if total_amount_remaining == 0
  #     next if ((lh.interest_due + lh.principal_due) == 0)
  #     timeliness = lh.date == received_on ? "normal" : (lh.date > received_on ? "advance" : "overdue")
  #     int_to_pay_today = [lh.interest_due, int_amount_remaining].min.round(2).round_to_nearest(rs.round_interest_to, rs.rounding_style)
  #     payments.push(:amount => int_to_pay_today, :received_on => received_on, :received_for => lh.date, 
  #                   :type => :interest, :timeliness => timeliness) if int_to_pay_today > 0
  #     int_amount_remaining -= int_to_pay_today
  #     puts "#{int_amount_remaining} interest remaining"
  #     prin_to_pay_today = [lh.principal_due, prin_amount_remaining].min.round(2).round_to_nearest(rs.round_interest_to, rs.rounding_style)
  #     payments.push(:amount => prin_to_pay_today, :received_on => received_on, :received_for => lh.date, 
  #                   :type => :principal, :timeliness => timeliness) if prin_to_pay_today > 0
  #     prin_amount_remaining -= prin_to_pay_today
  #     total_amount_remaining = (prin_amount_remaining + int_amount_remaining)
  #     puts total_amount_remaining
  #   end
  #   # then carry on with the rest of the loan history, paying sequentially as we go
  #   total_amount_remaining = total - payments.map{|x| x[:amount]}.sum
  #   puts "remaining: #{total_amount_remaining}"
  #   loan_history.all(:date.gt => received_on, :order => [:date]).each do |lh|
  #     puts "#{lh.date} : remaining => #{total_amount_remaining} p_due => #{lh.principal_due} i_due => #{lh.interest_due}"
  #     break if total_amount_remaining == 0
  #     next if ((lh.interest_due + lh.principal_due) == 0)
  #     timeliness = lh.date == received_on ? "normal" : (lh.date > received_on ? "advance" : "overdue")
  #     int_to_pay_today = [lh.interest_due, total_amount_remaining].min.round(2).round_to_nearest(rs.round_interest_to, rs.rounding_style)
  #     payments.push(:amount => int_to_pay_today, :received_on => received_on, :received_for => lh.date, 
  #                   :type => :interest, :timeliness => timeliness) if int_to_pay_today > 0
  #     total_amount_remaining -= int_to_pay_today
  #     prin_to_pay_today = [lh.principal_due, total_amount_remaining].min.round(2).round_to_nearest(rs.round_interest_to, rs.rounding_style)
  #     payments.push(:amount => prin_to_pay_today, :received_on => received_on, :received_for => lh.date, 
  #                   :type => :principal, :timeliness => timeliness) if prin_to_pay_today > 0
  #     total_amount_remaining -= prin_to_pay_today
  #   end
  #   payments.map{|p| puts "#{p[:received_on]} #{p[:type]} #{p[:amount]} #{p[:received_for]}"}
  #   payments
  # end

  def pay_reallocate_normal(total, received_on)
    # we need a separate one while reallocating due to the fact the interest_due becomes 0 after being paid and so we cannot use the one above while reallocating
    lh = info(received_on)
    {:interest => lh.interest_due + lh.interest_paid, :principal => total - (lh.interest_due + lh.interest_paid)}
  end

  # the way to delete payments from the db
  def delete_payment(payment, user)
    return false unless payment.loan.id == self.id
    payment.deleted_by = user
    if payment.destroy
      update_history
      return [true, payment]
    end
    [false, payment]
  end

  def delete_payments(payments, user)
    return false if payments.map{|p| p.loan.id != self.id}
    payments.map{|p| p.deleted_by = user}
    unless payments.map{|p| p.destroy}.include?(false)
      return [true, payments]
    else
      return [false, payments]
    end
  end

  def restore_payments(payments)
    payments.each{|p| p.deleted_at = nil; p.deleted_by = nil;}
    Payment.transaction do |t|
      if payments.map{|p| p.save}.include?(false)
        t.rollback
        return [false, payments]
      else
        return [true, payments]
      end
    end
  end


  def get_fee_payments(amount, date, received_by, created_by)
    fees = []
    fp = fees_payable_on(date)
    fs = fee_schedule
    pay_order = fs.keys.sort.map{|d| fs[d].keys}.flatten.uniq
    pay_order.each do |k|
      if fp.has_key?(k)
        # TODO -> make the received for proper. for this we have to write tests for multiple fees to make sure the mess above can be replaced with
        # something more sane
        p = Payment.new(:amount => [fp[k],amount].min, :type => :fees, :received_on => date, :comment => k, :fee => k,
                        :received_by => received_by, :created_by => created_by, :client => client, :loan => self, :received_for => Date.today)
        amount -= p.amount
        fp[k]  -= p.amount
        fees << p if p.amount > 0
      end
    end
    fees
  end
    

  def pay_fees(amount, date, received_by, created_by)
    pmts_to_make = get_fee_payments(amount, date, received_by, created_by)
    if pmts_to_make.empty?
      return {:status => false, :reason => "No fees to repay", :fees => []}
    else
      make_payments(pmts_to_make)
    end
  end
  # LOAN INFO FUNCTIONS - CALCULATIONS


  def first_payment_date
    if self.disbursal_date
      shift_date_by_installments(self.disbursal_date, 1)
    else
      nil
    end
  end


  def taken_over?
    taken_over_on || taken_over_on_installment_number
  end

  def actual_number_of_installments
    # we need this beacuse in loans with rounding, you may end up with more/less installments than advertised!!
    # crazy MFI product managers!!!
    number_of_installments
  end

  def payment_schedule
    # this is the fount of all knowledge regarding the scheduled payments for the loan. 
    # it feeds into every other calculation about the loan schedule such as get_scheduled, calculate_history, etc.
    # if this is wrong, everything about this loan is wrong.
    if self.taken_over?
      unless self.respond_to?(:taken_over_properly?)
        extend Loaner::TakeoverLoan 
      end
    end
    unless @loan_extended
      extend_loan
    end
    actual_payment_schedule
  end

  def actual_payment_schedule
    return @schedule if @schedule
    @schedule = {}
    return @schedule unless amount.to_f > 0

    principal_so_far = interest_so_far = fees_so_far = total = 0
    balance = amount
    fs = fee_schedule
    dd = disbursal_date || scheduled_disbursal_date
    fees_so_far = fs.has_key?(dd) ? fs[dd].values.inject(0){|a,b| a+b} : 0

    @schedule[dd] = {:principal => 0, :interest => 0, :total_principal => 0, :total_interest => 0, :balance => balance, :total => 0, :fees => fees_so_far}

    (1..actual_number_of_installments).each do |number|
      date      = installment_dates[number-1] 
      principal = scheduled_principal_for_installment(number).round(2)
      interest  = scheduled_interest_for_installment(number).round(2)

      principal_so_far += principal
      interest_so_far  += interest
      fees = fs.has_key?(date) ? fs[date].values.inject(0){|a,b| a+b} : 0
      fees_so_far += fees || 0
      balance -= principal
      @schedule[date] = {
        :principal                  => principal,
        :interest                   => interest,
        :fees                       => fees,
        :total_principal            => (principal_so_far),
        :total_interest             => (interest_so_far),
        :total                      => (principal_so_far + interest_so_far).round(2),
        :balance                    => balance.round(2),
      }
    end
    # we have to do the following to avoid the circular reference from total_to_be_received.
    total = @schedule[@schedule.keys.max][:total]
    @schedule.each { |k,v| v[:total_balance] = (total - v[:total]).round(2)}
    @schedule
  end

  
  def payments_hash(structs = nil)
    # this is the fount of knowledge for actual payments on the loan
    unless structs
      return @payments_cache if @payments_cache
      sql = %Q{
        SELECT SUM(amount * IF(type=1,1,0)) AS principal,
               SUM(amount * IF(type=2,1,0)) AS interest,
               received_on
        FROM payments
        WHERE (deleted_at IS NULL) AND (loan_id = #{self.id})
        GROUP BY received_on ORDER BY received_on}
      structs = id ? repository.adapter.query(sql) : []
    end
    @payments_cache = {}
    total_balance = total_to_be_received
    @payments_cache[disbursal_date || scheduled_disbursal_date] = {
      :principal => 0, :interest => 0, :total_principal => 0, :total_interest => 0, :total => 0, :balance => amount, :total_balance => total_balance
    }
    principal, interest, total = 0, 0, 0
    structs.each do |payment|
      # we know the received_on dates are in ascending order as we
      # walk through (so we can do the += thingy)

      @payments_cache[payment.received_on] = {
        :principal                 => payment.principal,
        :interest                  => payment.interest,
        :total_principal           => (principal += payment.principal),
        :total_interest            => (interest  += payment.interest),
        :total                     => (total     += payment.principal + payment.interest),
        :balance                   => amount - principal,
        :total_balance             => total_balance - total}
    end
    dates = (installment_dates + payment_dates)
    dates = dates.uniq.sort.reject{|d| d <= structs[-1].received_on} unless structs.blank?
    dates.each do |date|
      @payments_cache[date] = {:principal => 0, :interest => 0, :total_principal => principal, :total_interest => interest, :total => total, :balance => amount - principal, :total_balance => total_balance - total}
    end
    @payments_cache
  end

  
  # LOAN INFO FUNCTIONS - SCHEDULED

  def extend_loan
    unless @loan_extended
      if rs
        self.extend(Kernel.module_eval("Mostfit::PaymentStyles::#{rs.style.to_s}"))
        @loan_extended = true
      else
        raise ArgumentError, "No repayment style specified"
      end
    end
  end

  # these 2 methods define the pay back scheme
  # These are ONE BASED
  # typically reimplemented in subclasses
  def scheduled_principal_for_installment(number)
    # number unused in this implentation, subclasses may decide differently
    # therefor always supply number, so it works for all implementations
    extend_loan
    scheduled_principal_for_installment(number)
  end

  def scheduled_interest_for_installment(number)  # typically reimplemented in subclasses
    # number unused in this implentation, subclasses may decide differently
    # therefor always supply number, so it works for all implementations
    extend_loan
    scheduled_interest_for_installment(number)
  end

  # These info functions need not be overridden in derived classes.
  # We attmept to achieve speed by caching values for the duration of a request through a payment_schedule function
  # Later we write functions for
  #    scheduled_[principal, interest, total]_to_be_received
  #    scheduled_[principal, interest, total]_up_to(date)
  #    scheduled_[principal, interest, total]_on(date)

  def total_principal_to_be_received; payment_schedule.map{|k,v| v[:principal]}.reduce(:+); end
  def total_interest_to_be_received; payment_schedule.map{|k,v| v[:interest]}.reduce(:+); end
  def total_to_be_received
    ((total_principal_to_be_received>0 ? total_principal_to_be_received : amount) + total_interest_to_be_received)
  end

  def scheduled_principal_up_to(date); get_scheduled(:total_principal, date); end
  def scheduled_interest_up_to(date);  get_scheduled(:total_interest,  date); end
  def scheduled_total_up_to(date); (scheduled_principal_up_to(date) + scheduled_interest_up_to(date));  end


  def scheduled_principal_due_on(date); get_scheduled(:principal, date); end
  def scheduled_interest_due_on(date); get_scheduled(:interest, date); end
  def scheduled_total_due_on(date); scheduled_principal_due_on(dqte) + scheduled_interest_due_on(date); end
  # these 3 methods return scheduled amounts from a LOAN-OUTSTANDING perspective
  # they are purely calculated -- no calls to its payments or loan_history)
  def scheduled_outstanding_principal_on(date)  # typically reimplemented in subclasses
    return 0 if date < applied_on
    return amount if  date < (disbursal_date || scheduled_disbursal_date)
    amount - scheduled_principal_up_to(date)
  end
  def scheduled_outstanding_interest_on(date)  # typically reimplemented in subclasses
    return 0 if date < applied_on
    return total_interest_to_be_received if date < (disbursal_date || scheduled_disbursal_date)
    total_interest_to_be_received - scheduled_interest_up_to(date)
  end
  def scheduled_outstanding_total_on(date)
    return 0 if date < applied_on
    return total_to_be_received if date < (disbursal_date || scheduled_disbursal_date)
    total_to_be_received - scheduled_total_up_to(date)
  end
  # the number of payment dates before 'date' (if date is a payment 'date' it is counted in)
  # used to calculate the outstanding value, and in the views
  def number_of_installments_before(date)
    installment_dates.select{|d| d <= date}.count
  end


  # LOAN INFO FUNCTIONS - ACTUALS
  # the following methods basically count the payments (PAYMENT-RECEIVED perspective)
  # the last method makes the actual (optimized) db call and is cached

  def principal_received_up_to(date); get_actual(:total_principal, date); end
  def interest_received_up_to(date); get_actual(:total_interest, date); end
  def total_received_up_to(date); get_actual(:total,date); end

  def principal_received_on(date); get_actual(:principal, date); end
  def interest_received_on(date); get_actual(:interest, date); end
  def total_received_on(date); principal_received_on(date) + interest_received_on(date); end

  # these 3 method1 return overpayment amounts (PAYMENT-RECEIVED perspective)
  # negative values mean shortfall (we're positive-minded at intellecap)
  def principal_overpaid_on(date)
    (principal_received_up_to(date) - scheduled_principal_up_to(date))
  end
  def interest_overpaid_on(date)
    (interest_received_up_to(date) - scheduled_interest_up_to(date))
  end
  def total_overpaid_on(date)
    total_received_up_to(date) - scheduled_total_up_to(date)
  end
  # these 3 methods return actual outstanding amounts (LOAN-OUTSTANDING perspective)
  def actual_outstanding_principal_on(date)
    get_actual(:balance, date)
  end
  def actual_outstanding_interest_on(date)
    scheduled_outstanding_interest_on(date) - interest_overpaid_on(date)
  end
  def actual_outstanding_total_on(date)
    scheduled_outstanding_total_on(date) - total_overpaid_on(date)
  end
  def payment_dates
    payments.all.aggregate(:received_on)
  end

  def status(date = Date.today)
    get_status(date)
  end


  def get_status(date = Date.today, total_received = nil) # we have this last parameter so we can speed up get_status
                                                          # considerably by passing total_received, i.e. from history_for
    #return @status if @status
    @statuses ||= {}
    date = Date.parse(date)      if date.is_a? String

    return :applied_in_future    if applied_on.holiday_bump > date  # non existant
    return :applied              if applied_on.holiday_bump <= date and
                                 not (approved_on and approved_on.holiday_bump <= date) and
                                 not (rejected_on and rejected_on.holiday_bump <= date)
    return :approved             if (approved_on and approved_on.holiday_bump <= date) and not (disbursal_date and disbursal_date.holiday_bump <= date) and 
                                 not (rejected_on and rejected_on.holiday_bump <= date)
    return :rejected             if (rejected_on and rejected_on.holiday_bump <= date)
    return :written_off          if (written_off_on and written_off_on <= date)
    return :preclosed            if (preclosed_on and preclosed_on <= date)
    return :claim_settlement     if under_claim_settlement and under_claim_settlement.holiday_bump <= date
    return @statuses[date] if @statuses[date]
    total_received ||= total_received_up_to(date)
    principal_received ||= principal_received_up_to(date)
    return :disbursed            if (date == disbursal_date.holiday_bump) and total_received < total_to_be_received
    if total_received >= total_to_be_received
      @status =  :repaid
    elsif (amount - principal_received) <= EPSILON and (scheduled_interest_up_to(date)-interest_received_up_to(Date.today) <= EPSILON)
      @status =  :repaid
    elsif amount<=principal_received
      @status =  :repaid
    else
      @status =  :outstanding
    end
    @statuses[date] = @status
  end
  
  # LOAN INFO FUNCTIONS - DATES
  def installment_for_date(date = Date.today)
    installment_dates.select{|d| d <= date}.count
  end
  def date_for_installment(number)
    shift_date_by_installments(scheduled_first_payment_date, number-1)
  end
  def scheduled_maturity_date
    payment_schedule.keys.max
  end
  def scheduled_repaid_on
    # first payment is on "scheduled_first_payment_date", so number_of_installments-1 periods later
    # we find the scheduled_repaid_on date.
    scheduled_maturity_date
  end

  # the loan per se has no idea of calendars, etc. all it knows is that it needs some dates and for those dates it has to ask someone.
  # installment_source -> the method to call to get the fellow to ask for installment dates
  # installment source must respond to a :slice method which takes the following arguments
  # start_date
  # end date or number of dates to fetch
  #
  # Public: returns the dates on which SCHEDULED installments fall due for this loan
  def installment_dates
    return @_installment_dates if @_installment_dates
    @_installment_dates = self.send(installment_source).send(:slice, scheduled_first_payment_date, actual_number_of_installments)
  end


  #Increment/sync the loan cycle number. All the past loans which are disbursed are counted
  def update_cycle_number
    self.cycle_number=self.client.loans(:id.lt => id, :disbursal_date.not => nil).count+1
  end

  # HISTORY
  def update_history_caller
    update_history(false)
  end
  
  def update_history(forced=false)
    t = Time.now
    extend_loan
    return true if Mfi.first.dirty_queue_enabled and DirtyLoan.add(self) and not forced
    return if @already_updated and not forced
    return if self.history_disabled and not forced# easy when doing mass db modifications (like with fixutes)
    clear_cache
    update_history_bulk_insert
    Merb.logger.info "HISTORY EXEC TIME: #{(Time.now - t).round(4)} secs"
    @already_updated=true
    Merb.logger.info "LOAN CACHE UPDATE TIME: #{(Time.now - t).round(4)} secs"
  end

  # Public: Gives a list of all dates that are relevant to the loan
  def history_dates
    (([applied_on, approved_on, scheduled_disbursal_date, disbursal_date, written_off_on, scheduled_first_payment_date]).map{|d|
               (self.holidays[d] ? self.holidays[d].new_date : d)
     } +  installment_dates + payment_dates + loan_center_memberships.aggregate(:from)).compact.uniq.sort
  end

  # Public - returns the advance principal received and adjusted on a particular date
  # returns a hash like
  # {:received => {:principal => 100, :interest => 10, :fees => 0}...}, :adjusted => {:pr...}, :balance => {...}}
  def advances_on(date)
    payments.reload if payments.blank?
    # sum up all the payments that have timeliness marked as advance and received on this date
    received = {:principal => 0, :interest => 0, :fees => 0} + payments.select{|p| 
      p.received_on == date and p.timeliness == "advance"}.group_by(&:type).map{|k,v| [k,v.map(&:amount).sum]
    }.to_hash
    # sum up all the payments that have timeliness marked as advance and received for this date
    adjusted = {:principal => 0, :interest => 0, :fees => 0} + payments.select{|p| 
      p.received_for == date and p.timeliness == "advance"}.group_by(&:type).map{|k,v| [k,v.map(&:amount).sum]
    }.to_hash
    {:received => received, :adjusted => adjusted}
  end
  
  def calculate_history
    return @history_array if @history_array
    t = Time.now; @history_array = []
    now = DateTime.now

    # Crazy heisenbug is fixed by prefetching payments hash
    payments_hash
    
    # get fee payments. this is probably better of moved to functions in the fees_container
    fee_payments= Payment.all(:loan_id => id, :type => :fees).group_by{|p| p.received_on}.map do |k,v| 
      amt = v.is_a?(Array) ? (v.reduce(0){|s,h| s + h.amount} || 0) : v.amount
      [k,amt]
    end.to_hash
    ap_fees = fee_schedule.map{|k,v| [k,v.values.sum]}.to_hash
    dates = history_dates

    # initialize
    total_principal_due = total_interest_due = total_principal_paid = total_interest_paid = advance_principal_paid = advance_interest_paid = advance_principal_adjusted = advance_interest_adjusted = 0

    # find the actual total principal and interest paid.
    # this is helpful for adjusting interest and principal due on a particular date while taking into account future payments
    last_payments_hash = payments_hash.sort.last; 
    act_total_principal_paid = last_payments_hash[1][:total_principal]; act_total_interest_paid = last_payments_hash[1][:total_interest]
    last_status = 1; last_row = nil;
    dates.each_with_index do |date,i|
      i_num                                  = installment_for_date(date)
      scheduled                              = get_scheduled(:all, date)
      actual                                 = get_actual(:all, date)

      st                                     = get_status(date)
      outstanding                            = [:disbursed, :outstanding].include?(st) # is the loan outstanding?
      # if it is not, was it outstanding in the last period? 
      outstanding_at_start                   = outstanding ? true : (last_row ? [:disbursed, :outstanding].include?(STATUSES[last_row[:status]-1]) : true)
      # so, was it closed in this period?
      # this is important because a lot of stuff is calculated differently in the last period

      prin                                   = principal_received_on(date).round(2) 
      int                                    = interest_received_on(date).round(2)
      total_principal_paid                  += prin
      total_interest_paid                   += int

      scheduled_principal_due                = outstanding_at_start ? (i_num > 0 ? scheduled[:principal] : 0) : 0
      scheduled_interest_due                 = outstanding_at_start ? (i_num > 0 ? scheduled[:interest] : 0) : 0
      total_principal_due                   += outstanding_at_start ? scheduled[:principal].round(2) : 0
      total_interest_due                    += outstanding_at_start ? scheduled[:interest].round(2) : 0
      principal_due                          = outstanding_at_start ? [total_principal_due - act_total_principal_paid,0].max : 0
      interest_due                           = outstanding_at_start ? [total_interest_due - act_total_interest_paid,0].max : 0
      principal_due_today                    = [principal_due - ((last_row or Nothing)[:principal_due] || 0), 0].max
      interest_due_today                     = [interest_due  - ((last_row or Nothing)[:interest_due]  || 0), 0].max

      actual_outstanding_principal           = outstanding ? actual[:balance].round(2) : 0
      actual_outstanding_total               = outstanding ? actual[:total_balance].round(2) : 0
      actual_outstanding_interest            = outstanding ? (actual_outstanding_total - actual_outstanding_principal) : 0

      # ADVANCES
      # debugger if date == Date.new(2000,12,6)
      advance                                = advances_on(date)
      advance_principal_paid_today           = advance[:received][:principal]
      advance_principal_adjusted_today       = advance[:adjusted][:principal]
      advance_principal_outstanding          = (last_row ? last_row[:advance_principal_outstanding] : 0) + advance_principal_paid_today - advance_principal_adjusted_today

      advance_interest_paid_today            = advance[:received][:interest]
      advance_interest_adjusted_today        = advance[:adjusted][:interest]
      advance_interest_outstanding           = (last_row ? last_row[:advance_interest_outstanding] : 0) + advance_interest_paid_today - advance_interest_adjusted_today

      total_advance_outstanding              = advance_interest_outstanding + advance_principal_outstanding
      total_advance_paid_today               = advance_principal_paid_today + advance_interest_paid_today
      total_advance_adjusted_today           = advance_interest_adjusted_today + advance_principal_adjusted_today

      advance_principal_paid                += advance_principal_paid_today
      advance_principal_paid                 = outstanding_at_start ? advance_principal_paid : 0
      advance_interest_paid                 += advance_interest_paid_today
      advance_interest_paid                  = outstanding_at_start ? advance_interest_paid  : 0
      advance_principal_adjusted            += advance_principal_adjusted_today
      advance_interest_adjusted             += advance_interest_adjusted_today
      total_advance_paid                     = advance_principal_paid + advance_interest_paid 


      # FEES

      total_fees_due                         = ap_fees.select{|dt,af| dt <= date}.to_hash.values.sum || 0
      total_fees_paid                        = fee_payments.select{|dt,fp| dt <= date}.to_hash.values.sum || 0
      fees_due_today                         = ap_fees[date] || 0
      fees_paid_today                        = fee_payments[date] || 0

      

      principal_in_default                   = outstanding ? ((date <= Date.today) ? [0,total_principal_paid.round(2) - total_principal_due.round(2)].min : 0) : 0
      interest_in_default                    = outstanding ? ((date <= Date.today) ? [0,total_interest_paid.round(2) - total_interest_due.round(2)].min : 0)   : 0

      days_overdue                           = ((principal_in_default > 0  or interest_in_default > 0) and last_loan_history) ? last_loan_history[:days_overdue] + (date - last_loan_history[:date]) : 0
      
      center_for_date                        = center(date)
      center_id_for_date                     = center_for_date.id
      branch_id_for_date                     = (last_row ? (center_id_for_date == last_row[:center_id] ? last_row[:branch_id] : center_for_date.branch.id) : center_for_date.branch.id)

      next_change_date                       = loan_center_memberships.map(&:from).select{|x| x > date}.sort[0] || dates.max

      current_row = {
        :loan_id                             => self.id,
        :date                                => date,
        :holiday_id                          => 0,
        :last_status                         => last_status,
        :status                              => STATUSES.index(st) + 1,
        :scheduled_outstanding_principal     => scheduled[:balance].round(2),
        :scheduled_outstanding_total         => scheduled[:total_balance].round(2),
        :actual_outstanding_principal        => actual_outstanding_principal,
        :actual_outstanding_total            => actual_outstanding_total,
        :actual_outstanding_interest         => actual_outstanding_interest,
        :amount_in_default                   => actual[:balance].round(2) - scheduled[:balance].round(2),
        :principal_in_default                => principal_in_default,
        :interest_in_default                 => interest_in_default,
        :principal_at_risk                   => principal_in_default > 0 ? actual_outstanding_principal : 0,
        :scheduled_principal_due             => scheduled_principal_due,
        :scheduled_interest_due              => scheduled_interest_due,
        :principal_due                       => principal_due.round(2), 
        :interest_due                        => interest_due.round(2),
        :principal_due_today                 => principal_due_today.round(2),
        :interest_due_today                  => interest_due_today.round(2),
        :principal_paid                      => prin.round(2),
        :interest_paid                       => int.round(2),
        :total_principal_due                 => total_principal_due.round(2),
        :total_interest_due                  => total_interest_due.round(2),
        :total_principal_paid                => total_principal_paid.round(2),
        :total_interest_paid                 => total_interest_paid.round(2),
        :advance_principal_outstanding       => advance_principal_outstanding,
        :advance_interest_outstanding        => advance_interest_outstanding,
        :total_advance_outstanding           => advance_principal_outstanding + advance_interest_outstanding,
        :advance_principal_paid_today        => advance_principal_paid_today,
        :advance_interest_paid_today         => advance_interest_paid_today,
        :total_advance_paid_today            => advance_principal_paid_today + advance_interest_paid_today,
        :advance_principal_paid              => advance_principal_paid,
        :advance_interest_paid               => advance_interest_paid,
        :total_advance_paid                  => advance_interest_paid + advance_principal_paid,
        :advance_principal_adjusted          => advance_principal_adjusted,
        :advance_interest_adjusted           => advance_interest_adjusted,
        :advance_principal_adjusted_today    => advance_principal_adjusted_today,
        :advance_interest_adjusted_today     => advance_interest_adjusted_today,
        :total_advance_adjusted_today        => total_advance_adjusted_today,
        :total_fees_due                      => total_fees_due,
        :total_fees_paid                     => total_fees_paid,
        :fees_due_today                      => fees_due_today,
        :fees_paid_today                     => fees_paid_today,
        :composite_key                       => "#{id}.#{(i/10000.0).to_s.split('.')[1]}".to_f,
        :branch_id                           => branch_id_for_date,
        :center_id                           => center_id_for_date,
        :client_group_id                     => 0,                                # not tracking as not relevant for reports....or is it?
        :relevant_until                      => next_change_date,
        :client_id                           => client_id,
        :created_at                          => now,
        :funding_line_id                     => funding_line_id,
        :loan_product_id                     => loan_product_id,
        :days_overdue                        => days_overdue,
        :outstanding_count                   => outstanding ? 1 : 0,
        :outstanding                         => actual_outstanding_principal
      }
      # {:date_field => [:status, :loan_property]}
      {:applied_on => [:applied, :amt_applied_for], :approved_on => [:approved, :amt_sanctioned], :rejected_on => [:rejected, :amount], 
        :disbursal_date => [:disbursed, :amount], :written_off_on => [:written_off, :last_balance]}.each do |dt, action|
        if date == self.send(dt)
          current_row[action[0]] = action[1] == :last_balance ? last_row[:actual_outstanding_principal] : self.send(action[1])
          current_row["#{action[0].to_s}_count".to_sym] = 1 
        else
          current_row[action[0]] = 0
          current_row["#{action[0].to_s}_count".to_sym] = 0 
        end
      end

      current_row[:preclosed] =   (date == self.preclosed_on) ? current_row[:advance_principal_paid_today] : 0
      current_row[:preclosed_count] = (date == self.preclosed_on) ? 1 : 0

      @history_array << current_row
      last_status = current_row[:status]
      last_row = current_row
    end

    if taken_over?
      applied_on_date = self.applied_on.holiday_bump if self.applied_on
      @history_array = @history_array.reject{|h| h[:date] < applied_on_date}      
    end

    Merb.logger.info "History calculation took #{Time.now - t} seconds"
    @history_array
  end

  def update_history_bulk_insert
    # this gets the history from calculate_history and does one single insert into the database
    t = Time.now
    Merb.logger.error! "could not destroy the history" unless self.loan_history.destroy!
    sql = get_bulk_insert_sql("loan_history",calculate_history)
    t = Time.now
    repository.adapter.execute(sql)
    # reload the loan history
    self.loan_history.reload
    Merb.logger.info "update_history_bulk_insert done in #{Time.now - t}"
    return true
  end

  def write_off(written_off_on_date, written_off_by_staff)
    if written_off_on_date and written_off_by_staff and not written_off_on_date.blank? and not written_off_by_staff.blank?
      self.written_off_on = written_off_on_date
      self.written_off_by = (written_off_by_staff.class == StaffMember ? written_off_by_staff : StaffMember.get(written_off_by_staff))
      self.valid?
      self.save_self
    else
      false
    end
  end

  def set_amount
    return unless taken_over?
    # this sets the amount to be the outstanding amount unless it is already set
    amount = payment_schedule[payment_schedule.keys.min][:balance]
    amount_applied_for = amount
  end

  def set_loan_product_parameters
    self.repayment_style = self.loan_product.repayment_style unless self.repayment_style
    [:amount, :interest_rate, :number_of_installments].each do |attr|
      self.send("#{attr}=", self.loan_product.send("max_#{attr}")) if self.loan_product.send("max_#{attr}") == self.loan_product.send("min_#{attr}")
    end
    self.interest_rate = self.interest_rate / 100 if self.loan_product.max_interest_rate == self.loan_product.min_interest_rate #loan product stores it as 26, not 0.26 
    self.installment_frequency = self.loan_product.installment_frequency
  end

  def interest_calculation(balance)
    # need to have this is one place because a lot of functions need to know how interest is calculated given a balance
    # this is bound to become more complex as we add all kinds of dates 
    rs = self.repayment_style || self.loan_product.repayment_style
    ((balance * interest_rate) / get_divider).round(2).round_to_nearest(rs.round_interest_to, rs.rounding_style)
  end

  private

  include DateParser  # mixin for the hook "before :valid?, :parse_dates"
  include Misfit::LoanValidators

  # Sets the center of the loan to be whatever the client's center was when he applied for the loan.
  # this can subsequently be changed manually as we move stuff around.
  def set_center(center = nil, as_of = nil)
    # puts "set_center entry: #{loan_center_memberships}"
    if center and as_of
      LoanCenterMemberships.create(:club => center, :member => self, :from => as_of)
    else
      return if loan_center_memberships.size > 0
      return unless client
      client_centers = self.client.center(applied_on)
      if client_centers.count == 1
        self.center = client_centers[0]
      else
        raise "Need to specify a center as the client is a member of #{client_centers.count} centers"
      end
    end
  end

  def installment_source
    if loan_product and loan_product.has_validation?("scheduled_dates_must_be_center_meeting_days")
      set_center
      return "center" 
    end
    return "scheduler"
  end

  def scheduler
    return @schedulr if @schedulr
    @schedulr = Thermostat.new(:start_date => scheduled_first_payment_date, :n => actual_number_of_installments, :frequency => installment_frequency, :holidays => holidays)
  end
    


  def convert_blank_to_nil
    self.attributes.each{|k, v|
      if v.is_a?(String) and v.empty? and (self.class.send(k).type == Integer or self.class.send(k).type == Float)
        self.send("#{k}=", nil)
      end
    }
    self.amount      ||= self.amount_applied_for
  end

  def get_from_cache(cache, column, date)
    date = Date.parse(date) if date.is_a? String
    return 0 if cache.blank?
    if cache.has_key?(date)
      return (column == :all ? cache[date] : cache[date][column])
    else
      return 0 if (column == :principal or column == :interest)
      keys = cache.keys.sort
      if date < keys.min
        col = cache[keys.min].merge(:balance => amount, :total_balance => total_to_be_received)
        rv = (column == :all ? Marshal.load(Marshal.dump(col)) : Marshal.load(Marshal.dump(col[column])))
      elsif date >= keys.max
        rv = (column == :all ? Marshal.load(Marshal.dump(cache[keys.max])) : Marshal.load(Marshal.dump(cache[keys.max][column])))
      else
        keys.each_with_index do |k,i|
          if keys[[i+1,keys.size - 1].min] > date
            # http://thingsaaronmade.com/blog/ruby-shallow-copy-surprise.html
            rv = (column == :all ? Marshal.load(Marshal.dump(cache[k])) : cache[k][column])
            break
          end
        end
      end
      if rv.is_a? Hash
        rv[:principal] = 0; rv[:interest] = 0
      end
      rv
    end
  end

  def get_scheduled(column, date) 
    payment_schedule if @schedule.nil?
    get_from_cache(payment_schedule, column, date)
  end

  def get_actual(column, date)
    payments_hash if @payments_cache.nil?
    get_from_cache(payments_hash, column, date)
  end

  ## validations: read their method name and error to see what they do.
  def check_validity_of_cheque_number
    return true if not self.cheque_number or (self.cheque_number and self.cheque_number.blank?)
    return [false, "This cheque is already used"] if Loan.all(:cheque_number => self.cheque_number, :id.not => self.id).count>0
    return true
  end


  def dates_are_not_holidays
    h = ["scheduled_disbursal_date", "scheduled_first_payment_date"].map{|d| [d,Misfit::Config.holidays.include?(self.send(d))]}.reject{|e| e[1] == false}
    return true if h.blank?
    return [false, h.map{|f| f[0]}.join(", ") + " are holidays"]
  end

  def check_client_sincerity
    return [false, "Client is marked insincere and is not eligible for a loan"] if client and client.tags and client.tags.include?(:insincere)
    return true
  end

  def amount_greater_than_zero?
    return true if not amount.blank? and amount > 0
    [false, "Loan amount should be greater than zero"]
  end

  def interest_rate_greater_than_or_equal_to_zero?
    return true if interest_rate and interest_rate.to_f >= 0
    [false, "Interest rate should be greater than or equal to zero"]
  end

  def number_of_installments_greater_than_zero?
    return true if number_of_installments and number_of_installments.to_i > 0
    [false, "Number of installments should be greater than zero"]
  end

  def applied_before_appoved?
    return true if approved_on.blank? or (approved_on and applied_on and approved_on >= applied_on)
    [false, "Cannot be approved before it is applied for"]
  end

  def applied_before_rejected?
    return true if rejected_on.blank? or (rejected_on and applied_on and rejected_on >= applied_on)
    [false, "Cannot be rejected before it is applied for"]
  end

  def approved_before_disbursed?
    return true if disbursal_date.blank? or (disbursal_date and approved_on and disbursal_date >= approved_on)
    [false, "Cannot be disbursed before it is approved"]
  end

  def disbursed_before_validated?
    return true if validated_on.blank? or (disbursal_date and validated_on and disbursal_date <= validated_on)
    [false, "Cannot be validated before it is disbursed"]
  end

  def disbursed_before_written_off?
    return true if written_off_on.blank? or (disbursal_date and written_off_on and disbursal_date <= written_off_on)
    [false, "Cannot be written off before it is disbursed"]
  end

  def disbursed_before_suggested_written_off?
    return true if suggested_written_off_on.blank? or (disbursal_date and suggested_written_off_on and disbursal_date <= suggested_written_off_on)
    [false, "Cannot be suggested for write off before the loan is disbursed"]
  end

  def disbursed_before_write_off_rejected?
    return true if write_off_rejected_on.blank? or (disbursal_date and write_off_rejected_on and disbursal_date <= write_off_rejected_on)
    [false, "Cannot be rejected before the loan is disbursed"]
  end

  def rejected_before_suggested_write_off?
    return true if suggested_written_off_on.blank? or (write_off_rejected_on and suggested_written_off_on and write_off_rejected_on >= suggested_written_off_on)
    [false, "Cannot reject a loan for write off before it is suggested for write off."]
  end

  def applied_before_scheduled_to_be_disbursed?
    return true if scheduled_disbursal_date and applied_on and scheduled_disbursal_date >= applied_on
    [false, "Cannot be scheduled for disbusal before it is applied"]
  end

  def scheduled_disbursal_before_scheduled_first_payment?
    return true if scheduled_disbursal_date and scheduled_first_payment_date and scheduled_disbursal_date <= scheduled_first_payment_date
    [false, "The scheduled first payment date cannot precede the scheduled disbursal date"]
  end

  def properly_approved?
    return [false, "Funding Line must be set before approval"] unless funding_line
    return true if (approved_on and (approved_by or approved_by_staff_id)) or (approved_on.blank? and (approved_by.blank? or approved_by_staff_id.blank?))
    [false, "The approval date and the staff member that approved the loan should both be given"]
  end
  def properly_rejected?
    return true if (rejected_on and rejected_by) or (rejected_on.blank? and rejected_by.blank?)
    [false, "The rejection date and the staff member that rejected the loan should both be given"]
  end
  def properly_write_off_rejected?
    return true if (write_off_rejected_on and write_off_rejected_by) or (write_off_rejected_on.blank? and write_off_rejected_by.blank?)
    [false, "The date and the staff member that rejected the write off should both be given"]
  end
  def properly_written_off?
    return true if (written_off_on and written_off_by) or (written_off_on.blank? and written_off_by.blank?)
    [false, "The date of writing off the loan and the staff member that wrote off the loan should both be given"]
  end
  def properly_suggested_for_written_off?
    return true if (suggested_written_off_on and suggested_written_off_by) or (suggested_written_off_on.blank? and suggested_written_off_by.blank?)
    [false, "The date of suggesting write off loan and staff member who is suggesting to write off the loan should both be given"]
  end
  def properly_disbursed?
    return true if (disbursal_date and disbursed_by) or (disbursal_date.blank? and disbursed_by.blank?)
    [false, "The disbursal date and the staff member that disbursed the loan should both be given"]
  end
  def properly_validated?
    # if the validation_comment is not blank we also invalidate the model
    return true if (validated_on and validated_by) or (validated_on.blank? and validated_by.blank? and validation_comment.blank?)
    [false, "The validation date, the validating staff member the loan should both be given"]
  end
  def is_client_active
    if client and not client.active and self.new?
      return [false, "This is client is no more active"]
    end
    return true
  end
  def verified_cannot_be_deleted
    return true unless verified_by_user_id
    throw :halt
  end
  
  def check_insurance_policy
    return true unless insurance_policy
    return [false, "Insurance Policy is not valid"] unless insurance_policy.valid?
    return true

  end

  def get_divider
    case installment_frequency
    when :weekly
      52
    when :biweekly
      26
    when :bi_weekly
      26
    when :monthly
      12
    when :daily
      365
    end    
  end

end

module Loaner
  module TakeoverLoan
    def self.display_name
      "Take over #{super}"
    end


    def original_properties_specified?
      blanks = []
      [:original_amount, :original_disbursal_date, :original_first_payment_date].each do |o|
        blanks << o.to_s.humanize if send(o).blank?
      end
      return true if blanks.blank?
      return [false, "#{blanks.join(',')} must be specified"]
    end

    def taken_over_properly?
      if taken_over_on_installment_number and (taken_over_on_installment_number < number_of_installments)
        return true

      elsif taken_over_on and (taken_over_on < scheduled_maturity_date)
        return true
      else
        return [false, "Takeover date or installment does not jive with this loan"]
      end
    end  

#    def calculate_history
#      super
#      applied_on_date = self.applied_on.holiday_bump if self.applied_on
#      @history_array = @history_array.reject{|h| h[:date] < applied_on_date}      
#      return @history_array
#    end
    
    def actual_payment_schedule
      return @schedule if @schedule
      raise ArgumentError "This takeover loan is missing takeover information"  unless (self.taken_over_on || self.taken_over_on_installment_number)
      # TODO this exception is raised because we need to respect the first payment date and subsequent dates have to be 
      # adjusted to jive with everything else.
      self.taken_over_on_installment_number = number_of_installments_before(self.taken_over_on) if self.taken_over_on
      #store original values
      _amount = amount
      _disbursal_date = disbursal_date
      _scheduled_disbursal_date = scheduled_disbursal_date
      _fp_date = scheduled_first_payment_date
      # recreate the original loan
      self.scheduled_first_payment_date = original_first_payment_date
      saved_amount = self.amount unless self.new?
      self.amount = original_amount
      self.disbursal_date = original_disbursal_date
      # generate the payments_schedule
      super
      # chop off what doesn't belong to us
      self.taken_over_on ||= @schedule.keys.sort[(self.taken_over_on_installment_number) - 1]
      last_date = @schedule.reject{|k,v| k > self.taken_over_on}.keys.max
      total = @schedule[last_date][:total_balance]
      self.amount = saved_amount || @schedule[last_date][:balance].ceil
      @schedule = @schedule.reject{|k,v| k < last_date}
      # reset the original values
      self.disbursal_date = _disbursal_date
      self.scheduled_disbursal_date = _scheduled_disbursal_date
      self.scheduled_first_payment_date = _fp_date
      # adjust the first line of the payment_schedule
      dd = self.disbursal_date || self.scheduled_disbursal_date
      balance = saved_amount || @schedule[last_date][:balance]
      @schedule.delete(@schedule.keys.min)
      @schedule[dd] = {:principal => 0, :interest => 0, :total_principal => 0, :total_interest => 0, :balance => balance, :total => 0}

      # adjust all the dates
      adjusted_schedule = {}
      orig_dates = @schedule.keys.sort[1..-1]
      installment_dates.find_all{|d| d > last_date}.each_with_index do |d,i|
        adjusted_schedule[d] = payment_schedule[orig_dates[i]] if i < @schedule.count - 1
      end

      @schedule = {@schedule.keys.min => @schedule[@schedule.keys.min]} + adjusted_schedule
      # recreate the totals
      ti = tp = 0
      @schedule.keys.sort.each_with_index do |dt,idx|
        @schedule[dt][:total_interest] = ti += @schedule[dt][:interest]
        @schedule[dt][:principal] = idx == 0 ? 0 : (@schedule[@schedule.keys.sort[idx-1]][:balance] - @schedule[dt][:balance]).round(2)
        @schedule[dt][:total_principal] = tp += @schedule[dt][:principal]
        @schedule[dt][:total] = idx == 0 ? 0 : ti + tp
      end
      # do total_balance
      @schedule.each { |k,v| 
        v[:total_balance] = total - v[:total]
      }
      @schedule
    end
    
    def _show_original_cf
      #store original values
      _amount = amount
      _disbursal_date = disbursal_date
      _scheduled_disbursal_date = scheduled_disbursal_date
      _fp_date = scheduled_first_payment_date
      _original_amount = amount

      # recreate the original loan
      self.scheduled_first_payment_date = original_first_payment_date
      self.amount = original_amount
      self.disbursal_date = original_disbursal_date
      self.amount = original_amount
      # generate the payments_schedule
      clear_cache
      _show_cf
      self.disbursal_date = _disbursal_date
      self.scheduled_disbursal_date = _scheduled_disbursal_date
      self.scheduled_first_payment_date = _fp_date
      self.amount = _original_amount
    end

  end 
end 

