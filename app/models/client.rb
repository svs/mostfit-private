class Client
  include Paperclip::Resource
  include DateParser  # mixin for the hook "before :valid?, :parse_dates"
  include DataMapper::Resource
  include FeesContainer

  FLAGS = [:insincere]
  GENDER = ['', 'male', 'female']
  MARITAL_STATUS = ['', 'married', 'single', 'divorced', 'widow']
  RELATIONSHIP = ['', 'spouse', 'brother', 'sister', 'father', 'mother', 'son', 'daughter']
  PREMIUM_PAYMENT_FREQUENCY = ['','monthly', 'quarterly', 'half_yearly', 'annually']
  CLIENT_ASSETS = ['television', 'telephone', 'motorcycle', 'cycle', 'waterpump', 'computer']

  before :valid?, :parse_dates
  before :valid?, :convert_blank_to_nil
  before :valid?, :add_created_by_staff_member
  after  :save,   :check_client_deceased
  after  :save,   :levy_fees
  
  property :id,              Serial
  property :as_of,           Date
  property :reference,       String, :length => 100, :nullable => false, :index => true
  property :name,            String, :length => 100, :nullable => false, :index => true
  property :date_of_birth,   Date,   :index => true, :lazy => true
  property :spouse_name,     String, :length => 100, :lazy => true
  property :fathers_name,    String, :length => 100, :lazy => true
  property :address,         Text,   :lazy => true
  property :phone_number,    String, :length => 12,  :index => true, :lazy => true
  property :marital_status,  Enum.send('[]', *MARITAL_STATUS), :nullable => true, :index => true
  property :caste, Enum.send('[]', *['', 'sc', 'st', 'obc', 'general']), :default => '', :nullable => true, :lazy => true
  property :place_of_birth,  String, :length => 100, :index => true, :lazy => true
  property :nationality,     String, :length => 100, :index => true, :lazy => true
  property :kyc_documents,   Flag.send('[]',*KYC_DOCUMENTS)
  property :active,          Boolean, :default => true, :nullable => false, :index => true
  property :inactive_reason, Enum.send('[]', *INACTIVE_REASONS), :nullable => true, :index => true, :default => ''
  property :date_joined,     Date,    :index => true
  property :grt_pass_date,   Date,    :index => true, :nullable => true
  property :client_group_id, Integer, :index => true, :nullable => true
  property :created_at,      DateTime, :default => Time.now
  property :deleted_at,      ParanoidDateTime
  property :updated_at,      DateTime
  property :deceased_on,     Date, :lazy => true
  property :created_by_user_id,  Integer, :nullable => false, :index => true
  property :created_by_staff_member_id,  Integer, :nullable => false, :index => true
  property :verified_by_user_id, Integer, :nullable => true, :index => true
  property :tags, Flag.send("[]", *FLAGS)
  
  property :number_of_family_members, Integer, :length => 10, :nullable => true, :lazy => true
  property :family_1_name, String, :lazy => true
  property :family_1_gender, Enum.send('[]', *GENDER), :lazy => true, :nullable => true
  property :family_1_age, Integer, :lazy => true
  property :family_1_relationship, Enum.send('[]', *RELATIONSHIP), :lazy => true, :nullable => true
  property :family_1_marital_status,  Enum.send('[]', *MARITAL_STATUS), :lazy => true, :nullable => true
  property :family_1_occupation, String, :lazy => true
  property :family_1_education, String, :lazy => true
  property :family_1_nrega, String, :lazy => true
  property :family_1_source_of_income, String, :lazy => true
  property :family_1_monthly_income, Integer, :lazy => true
  property :family_2_name, String, :lazy => true
  property :family_2_gender, Enum.send('[]', *GENDER), :lazy => true, :nullable => true
  property :family_2_age, Integer, :lazy => true
  property :family_2_relationship, Enum.send('[]', *RELATIONSHIP), :lazy => true, :nullable => true
  property :family_2_marital_status,  Enum.send('[]', *MARITAL_STATUS), :lazy => true, :nullable => true
  property :family_2_occupation, String, :lazy => true
  property :family_2_education, String, :lazy => true
  property :family_2_nrega, String, :lazy => true
  property :family_2_source_of_income, String, :lazy => true
  property :family_2_monthly_income, Integer, :lazy => true
  property :family_3_name, String, :lazy => true
  property :family_3_gender, Enum.send('[]', *GENDER), :lazy => true, :nullable => true
  property :family_3_age, Integer, :lazy => true
  property :family_3_relationship, Enum.send('[]', *RELATIONSHIP), :lazy => true, :nullable => true
  property :family_3_marital_status,  Enum.send('[]', *MARITAL_STATUS), :lazy => true, :nullable => true
  property :family_3_occupation, String, :lazy => true
  property :family_3_education, String, :lazy => true
  property :family_3_nrega, String, :lazy => true
  property :family_3_source_of_income, String, :lazy => true
  property :family_3_monthly_income, Integer, :lazy => true
  property :family_4_name, String, :lazy => true
  property :family_4_gender, Enum.send('[]', *GENDER), :lazy => true, :nullable => true
  property :family_4_age, Integer, :lazy => true
  property :family_4_relationship, Enum.send('[]', *RELATIONSHIP), :lazy => true, :nullable => true
  property :family_4_marital_status,  Enum.send('[]', *MARITAL_STATUS), :lazy => true, :nullable => true
  property :family_4_occupation, String, :lazy => true
  property :family_4_education, String, :lazy => true
  property :family_4_nrega, String, :lazy => true
  property :family_4_source_of_income, String, :lazy => true
  property :family_4_monthly_income, Integer, :lazy => true

  property :total_monthly_income, Integer, :lazy => true
  property :total_annual_income, Integer, :lazy => true

  property :monthly_expenditure, Text, :lazy => true
  property :total_monthly_expenditure, Integer, :lazy => true
  property :total_annual_expenditure, Integer, :lazy => true
  property :total_monthly_savings, Integer, :lazy => true
  property :total_annual_savings, Integer, :lazy => true
  property :other_loan_details, Text, :lazy => true

  property :residence_survey_date, Date, :lazy => true
  property :residing_since_date, Date, :lazy => true
  property :residence_size, Enum.send('[]', *['', 'small', 'medium', 'large']) , :lazy => true, :default => ''
  property :residence_ownership, Enum.send('[]', *['', 'own', 'inherited', 'rented_or_state_owned']) , :lazy => true, :default => ''
  property :roof_construction, Enum.send('[]', *['', 'cement', 'tiled', 'tin']) , :lazy => true, :default => ''
  property :walls_construction, Enum.send('[]', *['', 'cement', 'brick', 'mud']) , :lazy => true, :default => ''
  property :power_connection, Boolean, :default => false, :lazy => true
  property :cooking_gas_connection, Boolean, :default => false, :lazy => true
  property :independent_toilet, Boolean, :default => false, :lazy => true
  property :phc_distance, Integer, :length => 10, :nullable => true, :lazy => true
  property :school_distance, Integer, :length => 10, :nullable => true, :lazy => true
  property :vet_care_centre_distance, Integer, :nullable => true, :lazy => true
  property :number_of_cattle, Integer, :lazy => true
  property :number_of_buffaloes, Integer, :lazy => true
  property :number_of_goats, Integer, :lazy => true
  property :number_of_bullocks, Integer, :lazy => true
  property :number_of_sheep, Integer, :lazy => true
  property :number_of_other_livestock, Integer, :lazy => true
  property :assets, Flag.send('[]', *CLIENT_ASSETS), :lazy => true
  property :other_assets, String, :lazy => true

  property :irrigated_land_own_fertile, Integer, :lazy => true
  property :irrigated_land_leased_fertile, Integer, :lazy => true
  property :irrigated_land_shared_fertile, Integer, :lazy => true
  property :irrigated_land_own_semifertile, Integer, :lazy => true
  property :irrigated_land_leased_semifertile, Integer, :lazy => true
  property :irrigated_land_shared_semifertile, Integer, :lazy => true
  property :irrigated_land_own_wasteland, Integer, :lazy => true
  property :irrigated_land_leased_wasteland, Integer, :lazy => true
  property :irrigated_land_shared_wasteland, Integer, :lazy => true
  property :not_irrigated_land_own_fertile, Integer, :lazy => true
  property :not_irrigated_land_leased_fertile, Integer, :lazy => true
  property :not_irrigated_land_shared_fertile, Integer, :lazy => true
  property :not_irrigated_land_own_semifertile, Integer, :lazy => true
  property :not_irrigated_land_leased_semifertile, Integer, :lazy => true
  property :not_irrigated_land_shared_semifertile, Integer, :lazy => true
  property :not_irrigated_land_own_wasteland, Integer, :lazy => true
  property :not_irrigated_land_leased_wasteland, Integer, :lazy => true
  property :not_irrigated_land_shared_wasteland, Integer, :lazy => true

  property :bank_name,      String, :length => 20, :nullable => true, :lazy => true
  property :bank_branch,    String, :length => 20, :nullable => true, :lazy => true
  property :account_number, String, :length => 20, :nullable => true, :lazy => true

  property :insured_value, Integer, :nullable => true, :lazy => true
  property :insurer, String, :nullable => true, :lazy => true
  property :insurance_premium, Integer, :nullable => true, :lazy => true
  property :premium_payment_frequency, Enum.send('[]', *PREMIUM_PAYMENT_FREQUENCY), :lazy => true, :nullable => true

  property :other_income, Integer, :length => 10, :nullable => true, :lazy => true
  property :total_income, Integer, :length => 10, :nullable => true, :lazy => true

  # fields before May 2011, preserved for backward compatibility and data on old clients
  property :religion, Enum.send('[]', *['', 'hindu', 'muslim', 'sikh', 'jain', 'buddhist', 'christian']), :default => '', :nullable => true, :lazy => true
  property :type_of_account, Enum.send('[]', *['', 'savings', 'current', 'no_frill', 'fixed_deposit', 'loan', 'other']), :lazy => true
  property :join_holder,    String, :length => 20, :nullable => true, :lazy => true
  property :member_literate, Enum.send('[]', *['', 'no', 'yes']), :default => '', :nullable => true, :lazy => true
  property :husband_litrate, Enum.send('[]', *['', 'no', 'yes']), :default => '', :nullable => true, :lazy => true
  property :other_productive_asset, String, :length => 30, :nullable => true, :lazy => true
  property :income_regular, Enum.send('[]', *['', 'no', 'yes']), :default => '', :nullable => true, :lazy => true
  property :client_migration, Enum.send('[]', *['', 'no', 'yes']), :default => '', :nullable => true, :lazy => true
  property :pr_loan_amount, Integer, :length => 10, :nullable => true, :lazy => true
  property :poverty_status, String, :length => 10, :nullable => true, :lazy => true
  property :children_girls_under_5_years, Integer, :length => 10, :default => 0, :lazy => true
  property :children_girls_5_to_15_years, Integer, :length => 10, :default => 0, :lazy => true
  property :children_girls_over_15_years, Integer, :length => 10, :default => 0, :lazy => true
  property :children_sons_under_5_years, Integer, :length => 10, :default => 0, :lazy => true
  property :children_sons_5_to_15_years, Integer, :length => 10, :default => 0, :lazy => true
  property :children_sons_over_15_years, Integer, :length => 10, :default => 0, :lazy => true
  property :not_in_school_working_girls, Integer, :length => 10, :default => 0, :lazy => true
  property :not_in_school_bonded_girls, Integer, :length => 10, :default => 0, :lazy => true
  property :not_in_school_working_sons, Integer, :length => 10, :default => 0, :lazy => true
  property :not_in_school_bonded_sons, Integer, :length => 10, :default => 0, :lazy => true

  property :as_of, Date

  is_versioned :on => :as_of


  validates_length :number_of_family_members, :max => 20
  validates_length :school_distance, :max => 200
  validates_length :phc_distance, :max => 500

  property   :client_type_id,     Integer, :default => 1
  has n, :loans
  has n, :payments
  has n, :insurance_policies
  has n, :attendances
  has n, :claims
  has n, :guarantors
  has n, :applicable_fees,    :child_key => [:applicable_id], :applicable_type => "Client"
  validates_length :account_number, :max => 20

  belongs_to :client_group
  belongs_to :occupation, :nullable => true
  belongs_to :client_type
  belongs_to :created_by,        :child_key => [:created_by_user_id],         :model => 'User'
  belongs_to :created_by_staff,  :child_key => [:created_by_staff_member_id], :model => 'StaffMember'
  belongs_to :verified_by,       :child_key => [:verified_by_user_id],        :model => 'User'

  is :versioned, :on => :as_of

  has_attached_file :picture,
    :styles => {:medium => "300x300>", :thumb => "60x60#"},
    :url => "/uploads/:class/:id/:attachment/:style/:basename.:extension",
    :path => "#{Merb.root}/public/uploads/:class/:id/:attachment/:style/:basename.:extension",
    :default_url => "/images/no_photo.jpg"

  has_attached_file :application_form,
    :styles => {:medium => "300x300>", :thumb => "60x60#"},
    :url => "/uploads/:class/:id/:attachment/:style/:basename.:extension",
    :path => "#{Merb.root}/public/uploads/:class/:id/:attachment/:style/:basename.:extension"

  has_attached_file :fingerprint,
    :url => "/uploads/:class/:id/:basename.:extension",
    :path => "#{Merb.root}/public/uploads/:class/:id/:basename.:extension"

  validates_length    :name, :min => 3
  validates_present   :date_joined
  validates_is_unique :reference
  validates_with_method  :verified_by_user_id,          :method => :verified_cannot_be_deleted, :if => Proc.new{|x| x.deleted_at != nil}
  validates_attachment_thumbnails :picture
  validates_with_method :date_joined, :method => :dates_make_sense
  validates_with_method :inactive_reason, :method => :cannot_have_inactive_reason_if_active
  
  # property :center_id, Integer

  has n, :client_center_memberships, :order => [:from], :child_key => [:member_id]
  #has n, :centers, :through => :client_center_membership
  

  def self.search(q, per_page=10)
    if /^\d+$/.match(q)
      all(:conditions => {:id => q}, :limit => per_page)
    else
      all(:conditions => ["reference=? or name like ?", q, q+'%'], :limit => per_page)
    end
  end

  # Public: updates the center memberships
  # Clients do not belong to Centers directly but through Memberships. In this case, a ClientCenterMembership
  # We are recreating the normal dm setters and getters to deal with this so we can still say @client.center = Center.last for example
  def center=(center)
    center, as_of = center.class == Array ? center : [center, self.date_joined]
    raise ArgumentError.new("expected a center") unless center.class == Center
    cm = ClientCenterMembership.new(:from => as_of, :club => center, :member => self)
    @c = nil; @center_id = center.id
    (self.client_center_memberships << cm)
  end

  def center_id=(center_id)
    center, as_of = center_id.class == Array ? center_id : [center_id, self.date_joined]
    self.center = Center.get(center)
  end

  def loans_for_center(center, as_of = Date.today)
    loans.select{|l| l.center(as_of) == center}
  end


  # Public: returns the center that a client is a member of on a particular Date
  #
  # as_of is a Date which defaults to today's date
  # returns an array of Centers, since the client can belong to multiple centers on a given day
  def center(as_of = nil)
    as_of ||= Date.today
    @c ||= {}
    @c[as_of] ||= Center.all(:id => ClientCenterMembership.as_of(as_of, client_center_memberships))
  end



  def pay_fees(amount, date, received_by, created_by)
    @errors = []
    fp = fees_payable_on(date)
    pay_order = fee_schedule.keys.sort.map{|d| fee_schedule[d].keys}.flatten
    pay_order.each do |k|
      if fees_payable_on(date).has_key?(k)
        pay = Payment.new(:amount => [fp[k], amount].min, :type => :fees, :received_on => date, :comment => k.name, :fee => k,
                          :received_by => received_by, :created_by => created_by, :client => self)        
        if pay.save_self
          amount -= pay.amount
          fp[k] -= pay.amount
        else
          @errors << pay.errors
        end
      end
    end
    @errors.blank? ? true : @errors
  end

  def self.flags
    FLAGS
  end

  def make_center_leader
    return "Already is center leader for #{center.name}" if CenterLeader.first(:client => self, :center => self.center)
    CenterLeader.all(:center => center, :current => true).each{|cl|
      cl.current = false
      cl.date_deassigned = Date.today
      cl.save
    }
    CenterLeader.create(:center => center, :client => self, :current => true, :date_assigned => Date.today)
  end

  def check_client_deceased
    if not self.active and not self.inactive_reason.blank? and [:death_of_client, :death_of_spouse].include?(self.inactive_reason.to_sym)
      loans.each do |loan|
        if (loan.status==:outstanding or loan.status==:disbursed or loan.status==:claim_settlement) and self.claims.length>0 and claim=self.claims.last
          if claim.stop_further_installments
            last_payment_date = loan.payments.aggregate(:received_on.max)
            #set date of stopping payments/claim settlement one ahead of date of last payment
            if last_payment_date and (last_payment_date > claim.date_of_death) 
              loan.under_claim_settlement = last_payment_date + 1
            elsif claim.date_of_death
              loan.under_claim_settlement = claim.date_of_death
            else
              loan.under_claim_settlement = Date.today
            end
            loan.save
          end
        end
      end
    end
  end

  def kyc_documents_supplied
    not self.kyc_documents.empty?
  end

  private
  def convert_blank_to_nil
    self.attributes.each{|k, v|
      if v.is_a?(String) and v.empty? and self.class.send(k).type==Integer
        self.send("#{k}=", nil)
      end
    }
    self.type_of_account = 0 if self.type_of_account == nil
    self.occupation = nil if self.occupation.blank?
    self.type_of_account = '' if self.type_of_account.nil? or self.type_of_account=="0"
  end

  def add_created_by_staff_member
    if @center_id and self.new?
      self.created_by_staff_member_id = Center.get(@center_id).manager_staff_id
    end
  end

  def dates_make_sense
    return true if not grt_pass_date or not date_joined 
    # return [false, "Client cannot join this center before the center was created"] if center and center.creation_date and center.creation_date > date_joined
    return [false, "GRT Pass Date cannot be before Date Joined"]  if grt_pass_date < date_joined
    return [false, "Client cannot die before he became a client"] if deceased_on and (deceased_on < date_joined or deceased_on < grt_pass_date)
    true
  end

  def verified_cannot_be_deleted
    return true unless verified_by_user_id
    throw :halt
    [false, "Verified client. Cannot be deleted"]
  end

  def self.death_cases(obj, from_date, to_date)
     d2 = to_date.strftime('%Y-%m-%d')
    if obj.class == Branch 
      from  = "branches b, centers c, clients cl, claims cm"
      where = %Q{
                cl.active = false AND cl.inactive_reason IN (2,3) AND cl.id = cm.client_id AND cm.claim_submission_date >= #{from_date.strftime('%Y-%m-%d')} AND cm.claim_submission_date <= 'd2' AND cl.center_id = c.id AND c.branch_id = b.id  AND b.id = #{obj.id}   
                };
      
    elsif obj.class == Center
      from  = "centers c, clients cl, claims cm"     
      where = %Q{
               cl.active = false AND cl.inactive_reason IN (2,3) AND cl.id = cm.client_id AND cm.claim_submission_date >= #{from_date.strftime('%Y-%m-%d')} AND cm.claim_submission_date <= 'd2' AND cl.center_id = c.id AND c.id = #{obj.id}   
                };
      
    elsif obj.class == StaffMember
      # created_by_staff_member_id
      from =  "clients cl, claims cm, staff_members sm"      
      where = %Q{
                cl.active = false AND cl.inactive_reason IN (2,3)  AND cl.id = cm.client_id AND cm.claim_submission_date >= #{from_date.strftime('%Y-%m-%d')} AND cm.claim_submission_date <= 'd2' AND cl.created_by_staff_member_id = sm.id AND sm.id = #{obj.id}    
                };
      
    end
    repository.adapter.query(%Q{
                             SELECT COUNT(cl.id)
                             FROM #{from}
                             WHERE #{where}
                           })
  end
  
   def self.pending_death_cases(obj,from_date, to_date) 
     if obj.class == Branch
       repository.adapter.query(%Q{
                                SELECT COUNT(cl.id)
                                FROM branches b, centers c, clients cl, claims cm
                                WHERE cl.active = false AND cl.inactive_reason IN (2,3)
                                AND cl.center_id = c.id AND c.branch_id = b.id 
                                AND b.id = #{obj.id} AND cl.id NOT IN (SELECT client_id FROM claims)     
                               })
       
     elsif obj.class == Center      
       repository.adapter.query(%Q{
                                SELECT COUNT(cl.id)
                                FROM centers c, clients cl, claims cm 
                                WHERE cl.active = false AND cl.inactive_reason IN (2,3)
                                AND cl.center_id = c.id AND c.id = #{obj.id} AND cl.id
                                NOT IN (SELECT client_id FROM claims )   
                              })

     elsif obj.class == StaffMember
       repository.adapter.query(%Q{
                                SELECT COUNT(cl.id)
                                FROM clients cl, claims cm, staff_members sm 
                                WHERE cl.active = false AND cl.inactive_reason IN (2,3)
                                AND cl.created_by_staff_member_id = sm.id AND sm.id = #{obj.id} AND cl.id
                                NOT IN (SELECT client_id FROM claims )
                                })
     end
   end
   
   def cannot_have_inactive_reason_if_active
     return [false, "cannot have a inactive reason if active"] if self.active and not inactive_reason.blank?
     return true
   end

 end
