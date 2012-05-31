class RepaymentOverdue < Report
  attr_accessor :date, :branch, :center, :branch_id, :center_id, :staff_member_id, :loan_product_id, :funder_id

  validates_with_method :is_valid


  def initialize(params, dates, user)
    @date   = (dates and dates[:date]) ? dates[:date] : Date.today
    @name   = "Report as of #{@date}"
    get_parameters(params, user)
  end

  def self.name
    "Repayment overdue register"
  end

  def name
    "Repayment overdue register as  of #{@date}"
  end

  def is_valid
    return [false, "Please choose a staff member and a date"] unless (@staff_member_id and @date)
    return true
  end

  def generate
    s = StaffMember.get(@staff_member_id)
    filter = s ? {:loan_history__center_id => s.centers.aggregate(:id)} : (@center_id ? {:loan_history__center_id => @center} : {})
    filter.merge!(@branch_id ? {:branch_id => @branch_id} : {})
    filter.merge!(:date => @date)

    q = DB.from(:loan_history, :clients, :centers, :branches, :loans)
    q = q.where(:loan_history__loan_id   => :loans__id,
                :loan_history__client_id => :clients__id, 
                :loan_history__center_id => :centers__id,
                :loan_history__branch_id => :branches__id).filter(filter)
    debugger
    q = q.filter{(interest_due + principal_due + fees_due_today) > 0}
    q = q.select(:branches__name  => :branch, 
                 :branches__id     => :branch_id,
                 :centers__name   => :center,
                 :centers__id     => :center_id,
                 :clients__name   => :client, 
                 :clients__id     => :client_id,
                 :loans__id       => :loan_id,
                 :interest_due    => :interest_due, 
                 :principal_due   => :principal_due,
                 :fees_due_today  => :fees_due,
                 :date            => :date)
    q.all

  end

end
