class LoanHistory
  include DataMapper::Resource
  
  property :loan_id,                   Integer, :key => true
  property :date,                      Date,    :key => true                      # the day that this record applies to
  property :relevant_until,            Date,    :index => true                    # this is a tough one but I will try to explain.
  # when moving stuff between centers, if a loan moves from center_id 1 to center_id 2 on date D and we ask for the data from center_id 1 
  # on date D + x, then the max composite key from this loan for that center will be returned but the problem is that those balances are no longer 
  # relevant, because the loan has moved on and the balance in center_1 is 0. Therefore, we need a way to make sure that
  # loan_history rows have a concept of relevance embedded into them. hope that made sense. email me (svs@svs.io) if you need more explanation.

  property :created_at,                DateTime                                   # automatic, nice for benchmarking runs
  property :run_number,                Integer, :required => true, :default => 0 
  property :current,                   Boolean                                    # tracks the row refering to the loans current status. we can query for these
                                                                                  # during reporting. I put it here to save an extra write to the db during update_history_now
  property :amount_in_default,          Float                                     # less normalisation = faster queries
  property :days_overdue,               Integer
  property :week_id,                    Integer                                   # good for aggregating.

  # some properties for similarly named methods of a loan:
  property :scheduled_outstanding_total,     Float, :required => true
  property :scheduled_outstanding_principal, Float, :required => true
  property :actual_outstanding_total,        Float, :required => true
  property :actual_outstanding_principal,    Float, :required => true
  property :actual_outstanding_interest,     Float, :required => true
  property :scheduled_principal_due,         Float, :required => true
  property :scheduled_interest_due,          Float, :required => true

  property :principal_due,                   Float, :required => true # this is total principal due - total interest due
  property :interest_due,                    Float, :required => true # and represents the amount payable today
  property :principal_due_today,             Float, :required => true # this is the principal and interest 
  property :interest_due_today,              Float, :required => true  #that has become payable today

  property :principal_paid,                  Float, :required => true
  property :interest_paid,                   Float, :required => true
  property :total_principal_due,             Float, :required => true
  property :total_interest_due,              Float, :required => true
  property :total_principal_paid,            Float, :required => true
  property :total_interest_paid,             Float, :required => true
  property :advance_principal_paid,          Float, :required => true   # these three rows
  property :advance_interest_paid,           Float, :required => true   # are for the total advance paid on the
  property :total_advance_paid,              Float, :required => true   # loan, without adjustments
  property :advance_principal_paid_today,    Float, :required => true
  property :advance_interest_paid_today,     Float, :required => true
  property :total_advance_paid_today,        Float, :required => true
  property :advance_principal_adjusted,      Float, :required => true
  property :advance_interest_adjusted,       Float, :required => true
  property :advance_principal_adjusted_today,      Float, :required => true
  property :advance_interest_adjusted_today,       Float, :required => true
  property :total_advance_adjusted_today,   Float, :required => true
  property :advance_principal_outstanding,   Float, :required => true  #
  property :advance_interest_outstanding,    Float, :required => true  # these are adjusted balances
  property :total_advance_outstanding,       Float, :required => true  #
  property :principal_in_default,            Float, :required => true
  property :interest_in_default,             Float, :required => true
  property :total_fees_due,                  Float, :required => true
  property :total_fees_paid,                 Float, :required => true
  property :fees_due_today,                  Float, :required => true
  property :fees_paid_today,                 Float, :required => true
  property :principal_at_risk,               Float, :required => true


  property :status,                      Enum.send('[]', *STATUSES)
  property :last_status,                 Enum.send('[]', *STATUSES)

  # add a column per status to track approvals, disbursals, etc.
  STATUSES.each do |status|
    property "#{status.to_s}_count".to_sym,  Integer, :required => true, :default => 0
    property status,        Float,   :required => true, :default => 0
  end
  

  property :client_id,                   Integer, :index => true
  property :client_group_id,             Integer, :index => true
  property :center_id,                   Integer, :index => true
  property :branch_id,                   Integer, :index => true
  #property :area_id,                     Integer, :index => true
  #property :region_id,                   Integer, :index => true
  property :holiday_id,                  Integer

  property :funding_line_id,             Integer, :index => true
  property :funder_id,                   Integer, :index => true
  property :loan_product_id,             Integer, :index => true
  property :loan_pool_id,                Integer, :required => false, :index => true
  property :composite_key, Float, :index => true



  belongs_to :loan
  belongs_to :client
  belongs_to :client_group, :required => false
  belongs_to :center         
  belongs_to :branch         

  belongs_to :holiday     
  belongs_to :funding_line, :funder, :loan_product

  
  validates_presence_of :loan,:scheduled_outstanding_principal,:scheduled_outstanding_total,:actual_outstanding_principal,:actual_outstanding_total

  def total_paid
    (principal_paid + interest_paid + fees_paid_today).round(2)
  end

  def total_due
    (principal_due + interest_due)
  end

  def total_advance_paid
    (advance_principal_paid_today + advance_interest_paid_today).round(2)
  end

  def total_default
    (principal_in_default + interest_in_default).abs.round(2)
  end

  def principal_defaulted_today
    [scheduled_principal_due - principal_paid,0].max
  end

  def interest_defaulted_today
    [scheduled_interest_due - interest_paid,0].max
  end
  
  def total_defaulted_today
    principal_defaulted_today + interest_defaulted_today
  end

  # this adjusts defaulted interest against advance principal
  def icash_interest_in_default
    [0,interest_in_default + total_advance_outstanding].min
  end

  def icash_total_in_default
    principal_in_default + icash_interest_in_default
  end


  COLS =   [:scheduled_outstanding_principal, :scheduled_outstanding_total, :actual_outstanding_principal, :actual_outstanding_total, :actual_outstanding_interest,
          :total_interest_due, :total_interest_paid, :total_principal_due, :total_principal_paid,
          :principal_in_default, :interest_in_default, :total_fees_due, :total_fees_paid, :total_advance_paid, :advance_principal_paid, :advance_interest_paid,
          :advance_principal_adjusted, :advance_interest_adjusted, :advance_principal_outstanding, :advance_interest_outstanding, :total_advance_outstanding, :principal_at_risk, 
          :outstanding_count, :outstanding]
  FLOW_COLS = [:principal_due, :principal_paid, :interest_due, :interest_paid,
               :scheduled_principal_due, :scheduled_interest_due, :advance_principal_adjusted, :advance_interest_adjusted,
               :advance_principal_paid, :advance_interest_paid, :advance_principal_paid_today, :advance_interest_paid_today, :fees_due_today, :fees_paid_today,
               :principal_due_today, :interest_due_today, :total_advance_paid_today, :advance_principal_adjusted_today, :advance_interest_adjusted_today, 
               :total_advance_adjusted_today] + STATUSES.map{|s| [s, "#{s}_count".to_sym] unless s == :outstanding}.compact.flatten


  ########### NICE NEW FUNCTIONS ###########################

  def self.get_composite_keys(selection = {})
    # this function is for speed.
    # it should return the same result as LoanHistory.all(selection).aggregate(:composite_key)
    q = "SELECT composite_key FROM loan_history WHERE " + get_where_from_hash(selection)
    repository.adapter.query(q).map{|x| x.to_f.round(4)}
  end

  def self.latest_keys(hash = {}, date = Date.today)
    # returns the composite key for the last row before date per loan from loan history and filters by hash
    #LoanHistory.all(hash.merge(:date.lte => date)).aggregate(:loan_id,:composite_key.max).map{|x| x[1]}

    # updated for speed
    q(%Q{
          SELECT loan_id, max(composite_key)
          FROM   loan_history 
          WHERE  #{(get_where_from_hash(hash) + " AND ") unless hash.blank?} 
                 date <= '#{date.strftime('%Y-%m-%d')}'
          GROUP BY loan_id
        }).map{|x| x[1].round(4)} 
  end

  def self.latest(hash = {}, date = Date.today)
    # returns the last LoanHistory per loan before date
    LoanHistory.all(:composite_key => LoanHistory.latest_keys(hash, date))
  end

  def self.latest_by_status(options)
    # to select, for example, only outstanding loans on a particular date,
    # we cannot simply say LoanHistory.latest(:status => :outstanding, @date)
    # because this will simply return the last row when the loan was outstanding even if the loan has been
    # repaid before @date. Hence we need to take a circuituous route where we first select the latest row and then filter for outstanding loans
    selection = options.except(:status)
    date = options[:date] || Date.today
    status = options[:status]
    cks = LoanHistory.latest_keys(selection,date)
    LoanHistory.all(:composite_key => cks, :status => status)
  end
    


  def self.latest_sum(hash = {}, date = Date.today, group_by = [], cols = [])
    # sums up the latest loan_history row per loan, even groups by any attribute
    LoanHistory.composite_key_sum(LoanHistory.latest_keys(hash,date),group_by, cols)
  end


  # Takes all the loan history rows per params and aggregates them.
  # params is a Hash of {:branch_id => , :center_id =>, :from_date, :to_date}
  # if params is empty, report is split up per branch. If a a branch is given, report is provided for the centers in that branch
  # TODO - add more fancy selection support here
  def self.get_aggregate_report(params)
    debugger
    params = params.map{|k,v| [k.to_sym, v]}.to_hash
    from_date = params[:from_date].class == String ? Date.parse(params[:from_date]) : params[:from_date]
    to_date   = params[:to_date].class   == String ? Date.parse(params[:to_date])   : params[:to_date]
    lh = DB[:loan_history].filter(params.only(:branch_id, :center_id).select{|k,v| !v.blank?}.to_hash)
    gb = params[:branch_id].blank? ? :branch_id : (params[:center_id].blank? ? :center_id : :loan_id) #group_by
    flow_sum = lh.filter(:date => from_date..to_date).select(*([gb] + (FLOW_COLS).map{|c| :sum[c]})).group_by(gb)
    flow_sum = flow_sum.all.map{|x| [x[gb], x]}.to_hash
    bal_keys = lh.group_by(:loan_id).filter{ date < to_date }.filter{ relevant_until > from_date}.select_map(:max[:composite_key])
    bal_sum = lh.filter(:composite_key => bal_keys).select(*([gb] + (COLS).map{|c| :sum[c]})).group_by(gb)
    bal_sum = bal_sum.all.map{|x| [x[gb], x]}.to_hash
    bal_sum + flow_sum
  end
end
