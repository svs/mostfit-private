class InsurancePolicy
  include DataMapper::Resource
  include FeesContainer

  POLICY_STATUSES = [:active, :expired, :claim_pending, :claim_settled]
  COVER_FOR       = [:self, :spouse, :both, :son, :daughter, :mother, :father, :other]
  property :id, Serial
  property :application_number, String, :required => false
  property :policy_no, String, :required => false
  property :sum_insured, Integer, :required => true
  property :premium, Integer, :required => true
  property :date_from, Date, :required => true
  property :date_to, Date, :required => true
  property :nominee, String, :required => false
  property :status, Enum.send("[]", *POLICY_STATUSES), :required => false
  property :cover_for, Enum.send("[]", *COVER_FOR), :required => false, :default => 'self'
  property :beneficiary_name, Text

  belongs_to :insurance_product
  belongs_to :client
  belongs_to :loan, :required => false
  has n, :applicable_fees,    :child_key => [:applicable_id], :applicable_type => "InsurancePolicy"
  after  :save,   :levy_fees

  before :valid?, :set_status

  validates_with_method :end_date_after_start_date

  def self.statuses
    POLICY_STATUSES
  end

  def description
    "#{insurance_product.name}: Rs.#{sum_insured}"
  end

  # [:applied_on, :approved_on, :disbursal_date].each do |p|
  #   define_method "loan_#{p}" do 
  #     loan.send(p) if loan
  #   end
  # end

  private
  def set_status
    if self.date_to and self.is_a?(Date)
      self.status = Date.today > self.date_to ? :expired : :active    
    end
    
    # set other parameters if loan is attached and they are not set
    if self.loan
      self.client = self.loan.client unless self.client
      self.date_from = self.loan.disbursal_date if not self.date_from and self.loan.disbursal_date
      self.date_from = self.loan.disbursal_date if not self.date_from and self.loan.scheduled_disbursal_date
    end
  end

  def end_date_after_start_date
    return [false, "End date must be after start date"] if date_to.is_a?(Date) and date_from.is_a?(Date) and date_to < date_from
    true
  end
end
