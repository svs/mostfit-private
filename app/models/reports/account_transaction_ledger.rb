class AccountTransactionLedger < Report
  attr_accessor :from_date, :to_date, :branch, :center, :branch_id, :center_id, :staff_member_id, :loan_product_id

  validates_with_method :from_date, :date_should_not_be_in_future


  def initialize(params, dates, user)
    @from_date = (dates and dates[:from_date]) ? dates[:from_date] : Date.today
    @to_date   = (dates and dates[:to_date]) ? dates[:to_date] : Date.today
    @name   = "Report from #{@from_date} to #{@to_date}"
    get_parameters(params, user)
  end

  def self.name
    "Transaction ledger for accounting"
  end

  def generate
    return @data if @data
    default_select = { 
      :payments__id            => :id,        
      :payments__received_on  => :date, 
      :payments__received_for => :received_for, 
      :payments__timeliness   => :timeliness, 
      :payments__amount       => :amount, 
      :branches__name         => :branch, 
      :centers__name          => :center,
      :clients__name          => :client,
      :loan_products__name    => :product,
      :payments__created_at   => :created_at,
      :fees__name             => :fee_name
    }
    default_from = [:branches, :payments, :centers, :clients, :loans, :loan_products]
    default_where = {:payments__c_branch_id => :branches__id, :payments__c_center_id => :centers__id, :payments__client_id => :clients__id,
      :payments__loan_id => :loans__id, :loans__loan_product_id => :loan_products__id}
    # first get all the transctions where the received on is today
    normal = DB[:payments].left_join(:fees, :id => :fee_id).from(default_from).where(default_where.merge(:received_on => @from_date..@to_date))
    is_advance = :if.sql_function(:received_for > :received_on,'advance ','')
    type = :concat.sql_function(is_advance, :elt.sql_function(:type, "principal","interest","fees"))
    todays_transactions = normal.select(default_select.merge(type => :type))

    # then get all the transactions where received_for is today and mark them as advances adjusted
    aps = DB[:payments].left_join(:fees, :id => :fee_id).from(default_from).where(default_where.merge(:received_for => @from_date..@to_date)).filter('received_for <> received_on')
    type = :elt.sql_function(:type, "advance principal adjusted","advance interest adjusted","advance fees adjusted")
    new_id = :concat.sql_function(:payments__id, :elt.sql_function(:type, '.11','.12','.13'))
    s = default_select.dup
    s.delete(:payments__id)
    advances = aps.select(s.merge(type => :type, new_id => :id))
    debugger
    # then get [:disbursal, :write_off]
    disbursals = DB.fetch(%Q{
      select loans.id + 0.01 as id, now() as created_at, disbursal_date as date,clients.name as client,loans.id + 0.01,branches.name as branch, loan_products.name as product, 
      centers.name as center, amount, 'disbursal' as type from clients,loans join memberships on loans.id = member_id join centers 
      on club_id = centers.id, branches, loan_products where memberships.type = 'LoanCenterMembership' and `from` <= disbursal_date 
      and upto >= disbursal_date and disbursal_date = '2012-4-3' and centers.branch_id = branches.id 
      and loans.loan_product_id = loan_products.id and loans.client_id = clients.id})
    @data = todays_transactions.all + advances.all + disbursals.all
    
  end

  def to_csv_file
    self.generate
    keys = [:id, :created_at, :source, :date, :received_for, :type, :amount, :client, :branch, :center, :product, :fee_name]
    rv = [keys.map(&:to_s).to_csv]
    @data.each do |d|
      d[:source] = 'sahayog'
      rv << keys.map{|k| d[k]}.to_csv
    end
    rv.join
  end
end
