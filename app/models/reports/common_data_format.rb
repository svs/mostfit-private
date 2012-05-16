#module Highmark
  
  class CommonDataFormat < Report
    
    attr_accessor :from_date, :to_date 
    
    include Mostfit::Reporting
    
    def initialize(params, dates, user)
      @to_date   = (dates and dates[:to_date]) ? dates[:to_date] : Date.today
      @from_date = (dates and dates[:from_date]) ? dates[:from_date] : @to_date << 3
      get_parameters(params, user)
    end
    
    def name
      "Common Data Format Report for #{Mfi.first.name} as on #{@to_date}"
    end
    
    def self.name
      "Common Data Format Report"
    end
    
    def generate
      @data = { "CNSCRD" => [], "ADRCRD" => [], "ACTCRD" => [] }
      folder = File.join(Merb.root, "doc", "csv", "reports")      
      FileUtils.mkdir_p(folder)

      filename_cnscrd = File.join(folder, "#{self.name}-customer.csv")
      filename_adrcrd = File.join(folder, "#{self.name}-address.csv")
      filename_actcrd = File.join(folder, "#{self.name}-accounts.csv")
      File.new(filename_cnscrd, "w").close
      File.new(filename_adrcrd, "w").close
      File.new(filename_actcrd, "w").close

      puts "attendance...."
      #attendance_record = Center.all.map{|x| [x.id, Attendance.all(:center_id => x.id).aggregate(:client_id, :client_id.count).to_hash]}.to_hash
      puts "absent...."
      #absent_record = Center.all.map{|x| [x.id, Attendance.all(:center_id => x.id, :status => "absent").aggregate(:client_id, :client_id.count).to_hash]}.to_hash
      append_to_file_as_csv([headers["CNSCRD"]], filename_cnscrd)
      append_to_file_as_csv([headers["ADRCRD"]], filename_adrcrd)
      append_to_file_as_csv([headers["ACTCRD"]], filename_actcrd)
      # REPAID, WRITTEN_OFF AND PRECLOSED loans are treated as closed loans
      all_loans = Loan.all(:fields => [:id]).map{|x| x.id}.uniq
      cut_off_date = @from_date
      ineligible_written_off_loans = LoanHistory.all(:status => :written_off, :date.lte => cut_off_date).aggregate(:loan_id)
      ineligible_preclosed_loans = LoanHistory.all(:status => :preclosed, :date.lte => cut_off_date).aggregate(:loan_id)
      ineligible_repaid_loans = LoanHistory.all(:status => :repaid, :date.lte => cut_off_date).aggregate(:loan_id)
      eligible_loans = all_loans - (ineligible_written_off_loans + ineligible_preclosed_loans + ineligible_repaid_loans)
      puts "found #{eligible_loans.count} eligible loans"
      
      eligible_loans[0..1000].each_with_index do |l_id, i|
        l = Loan.get(l_id)
        client = l.client
	next if client.nil? 
        center = client.center
        branch = center.branch
        if l.status(@to_date) == :outstanding
          lh = l.loan_history(:status => :outstanding, :date.lte => @to_date).last  # if the loan is outstanding then the last record of loan history is the latest state of the loan
        else
          lh = l.loan_history(:status => l.status(@to_date), :date.lte => @to_date).first # this is because after a loan is written off, preclosed or under claim settlement all the succeeding loan history records of that loan change to the same status. Hence we go for the first status and in case of repaid it is always the last
        end
        lh = l.loan_history(:date.lte => @to_date).last if lh.nil? # this is there because in some cases it has been observed that the l.status function returns :repaid but the last loan history record for that loan is that of :outstanding.
        next if lh.nil?
        debugger if lh.nil?
        print "#{i} ".green
        
        rows = row(l, client, center, branch, lh, attendance_record, absent_record)

        #the following lines of code replace the blanks with nils
        rows["CNSCRD"].map!{|x| x = (x == "" ? nil : x)}
        rows["ADRCRD"].map!{|x| x = (x == "" ? nil : x)}
        rows["ACTCRD"].map!{|x| x = (x == "" ? nil : x)}

        unless @data["CNSCRD"].include?(rows["CNSCRD"])
          @data["CNSCRD"] << rows["CNSCRD"]
          append_to_file_as_csv([rows["CNSCRD"]], filename_cnscrd)
          append_to_file_as_csv([rows["ADRCRD"]], filename_adrcrd)
        end
        append_to_file_as_csv([rows["ACTCRD"]], filename_actcrd)
      end
      puts "DONE!".green
      return true
    end
    
    private

    def append_to_file_as_csv(data, filename)
      FasterCSV.open(filename, "a", {:col_sep => "|"}) do |csv|
        data.each do |datum|
          csv << datum
        end
      end
    end
    
    def headers
      _headers ||= { 
        "CNSCRD" => ["Bank ID",
                     "Segment Identifier",
                     "Member Identifier",
                     "Branch Identifier",
                     "Kendra/Centre Identifier",
                     "Group Identifier",
                     "Member Name 1",
                     "Member Name 2",
                     "Member Name 3",
                     "Alternate Name of Member",
                     "Member Birth Date",
                     "Member Age",
                     "Member's age as on date",
                     "Member Gender Type",
                     "Marital Status Type",
                     "Key Person's name",
                     "Key Person's relationship",
                     "Member relationship Name 1",
                     "Member relationship Type 1",
                     "Member relationship Name 2",
                     "Member relationship Type 2",
                     "Member relationship Name 3",
                     "Member relationship Type 3",
                     "Member relationship Name 4",
                     "Member relationship Type 4",
                     "Nominee Name",
                     "Nominee relationship",
                     "Nominee Age",
                     "Voter's ID",
                     "UID",
                     "PAN",
                     "Ration Card",
                     "Member Other ID 1 Type description",
                     "Member Other ID 1",
                     "Member Other ID 2 Type description",
                     "Member Other ID 2 ",
                     "Member Other ID 3 Type description",
                     "Member Other ID 3",
                     "Telephone Number 1 type Indicator",
                     "Member Telephone Number 1",
                     "Telephone Number 2 type Indicator",
                     "Member Telephone Number 2",
                     "Poverty Index",
                     "Asset ownership indicator",
                     "Number of Dependents",
                     "Bank Account - Bank Name",
                     "Bank Account - Branch Name",
                     "Bank Account - Account Number",
                     "Occupation",
                     "Total Monthly Family Income",
                     "Monthly Family Expenses",
                     "Member's Religion",
                     "Member's Caste",
                     "Group Leader indicator",
                     "Center Leader indicator",
                     "Dummy",
                     "Member Name 4",
                     "Member Name 5",
                     "Passport Number",
                     "Parent ID",
                     "EXTRACTION FILE ID",
                     "SEVERITY"],
        "ADRCRD" => ["Bank ID",
                     "Segment Identifier",
                     "Member's Permanent Address",
                     "State Code ( Permanent Address)",
                     "Pin Code ( Permanent Address)",
                     "Member's Current Address",
                     "State Code ( Current Address)",
                     "Pin Code ( Current Address)",
                     "Dummy",
                     "Parent ID",
                     "EXTRACTION FILE ID",
                     "SEVERITY"],
        "ACTCRD" => ["Bank ID",
                     "Segment Identifier",
                     "Unique Account Reference number",
                     "Account Number",
                     "Branch Identifier",
                     "Kendra/Centre Identifier",
                     "Loan Officer for Originating the loan",
                     "Date of Account Information",
                     "Loan Category",
                     "Group Identifier",
                     "Loan Cycle-id",
                     "Loan Purpose",
                     "Account Status ",
                     "Application date",
                     "Sanctioned Date",
                     "Date Opened/Disbursed",
                     "Date Closed (if closed)",
                     "Date of last payment",
                     "Applied For amount",
                     "Loan amount Sanctioned",
                     "Total Amount Disbursed (Rupees)",
                     "Number of Installments",
                     "Repayment Frequency",
                     "Minimum Amt Due/Instalment Amount",
                     "Current Balance (Rupees)",
                     "Amount Overdue (Rupees)",
                     "DPD (Days past due)",
                     "Write Off Amount (Rupees)",
                     "Date Write-Off (if written-off)",
                     "Write-off reason (if written off)",
                     "No. of meetings held",
                     "No. of meetings missed",
                     "Insurance Indicator",
                     "Type of Insurance",
                     "Sum Assured/Coverage",
                     "Agreed meeting day of the week",
                     "Agreed Meeting time of the day",
                     "Dummy",
                     "Old Member Code", #in case the member id  number has changed
                     "Old Member Short Number", #NULL
                     "Old Account Number", # in case the account number has changed
                     "CIBIL Act Status", # has to be populated 
                     "Asset Classification", #if the account is doubtful, or if the loan is not being paid regularly
                     "Member Code", # NULL
                     "Member Short Number", #NULL
                     "Account Type", #NULL
                     "Ownership Indicator", #NULL
                     "Parent ID", 
                     "EXTRACTION FILE ID", 
                     "SEVERITY"]
      }
    end
    
    def row(loan, client, center, branch, loan_history, attendance_record, absent_record)
      _row = {
        "CNSCRD" => [client.id.to_s.truncate(100, ""),
                     "CNSCRD",
                     client.id.to_s.truncate(35, ""), 
                     branch.id.to_s.truncate(30, ""), 
                     center.id.to_s.truncate(30, ""),
                     client.client_group_id.to_s.truncate(20, ""),
                     client.name.truncate(100, ""),
                     nil, # member name 2
                     nil, # member name 3
                     nil, # alternate name of member
                     (client.date_of_birth ? client.date_of_birth.strftime("%d%m%Y").truncate(8,"") : nil),
                     ((client.date_joined and client.date_of_birth) ? (client.date_joined.year - client.date_of_birth.year).to_s.truncate(3, "") : nil),
                     (client.date_joined ? client.date_joined.strftime("%d%m%Y").truncate(8,"") : nil),
                     "F", #(client.gender.empty? ? nil : gender[client.gender.to_sym]), #(client.respond_to?(:gender) ? gender[client.send(:gender).to_sym] : gender[:female]).truncate(1, ""), # ideally it should be untagged
                     (client.spouse_name.empty? ? marital_status[:untagged] : marital_status[:married]),
                     client.spouse_name.truncate(100, ""),
                     key_person_relationship(client, 'spouse'),
                     #(client.gender == "female" ? key_person_relationship['husband'] : key_person_relationship['wife']),
                     nil, #client.family_member_1_name, #member 1
                     nil, #(key_person_relationship(client, client.family_member_1_relationship)), #relationship with member 1
                     nil, #client.family_member_2_name, #member 2
                     nil, #(key_person_relationship(client, client.family_member_2_relationship)), #relationship with member 2
                     nil, #client.family_member_3_name, #member 3
                     nil, #(key_person_relationship(client, client.family_member_3_relationship)), #relationship with member 3
                     nil, #client.family_member_4_name, #member 4
                     #(key_person_relationship(client, client.family_member_4_relationship)), #relationship with member 4
                     nil, # client.guarantor_name, #nominee name
                     nil, # key_person_relationship[client.guarantor_relationship], #nominee relationship
                     nil, # ((client.date_joined and client.guarantor_date_of_birth) ? (client.date_joined.year - client.guarantor_date_of_birth.year).to_s.truncate(3, "") : nil), #nominee age
                     nil, #(client.type_of_id == "voter_id" ? client.reference.truncate(20, "") :  nil), #voters id
                     nil, # UID
                     nil, #(client.type_of_id == "pan_card" ? client.reference.truncate(15, "") : nil), #PAN
                     nil, #(client.type_of_id == "ration_card" ? client.reference.truncate(20, "") : nil), #ration card
                     nil, #client.type_of_id.to_s.truncate(20, ""), #other id type description 1
                     client.reference.truncate(30, ""), #other id 1
                     nil, #other id type description 2
                     nil, #other id 2
                     nil, #other id type description 3
                     nil, #other id 3
                     phone[:untagged], #telephone number type 1
                     nil, #client.phone_number.truncate(15, ""), #telephone number 1
                     nil, #telephone number type 2
                     nil, #telephone number 2
                     client.poverty_status.to_s.truncate(20, ""),
                     ((client.other_productive_asset.nil? || client.other_productive_asset.empty?) ? asset_ownership_indicator[:no] : asset_ownership_indicator[:yes]),
                     client.number_of_family_members.to_s.truncate(2, ""), #number of dependents
                     client.bank_name.to_s.truncate(50, ""),
                     client.bank_branch.to_s.truncate(50, ""),
                     client.account_number.to_s.truncate(35, ""),
                     (client.occupation.nil? ? nil : client.occupation.name.truncate(50, "")),
                     client.total_income.to_s.truncate(9, ""),
                     nil, #client.total_expenses.to_s.truncate(9, ""), #expenditure
                     religion[client.religion],
                     client.caste.truncate(30, ""),
                     group_leader_indicator[:untagged],
                     (CenterLeader.first(:client_id => client.id).nil? ? center_leader_indicator[:no] : center_leader_indicator[:yes]),
                     nil, #dummy reserved for future use
                     nil, #member name 4
                     nil, #member name 5
                     nil, #passport number
                     nil, #parent id
                     nil,
                     nil
                    ],
        "ADRCRD" => [client.id.to_s.truncate(100, ""),
                     "ADRCRD",  
                     client.address.gsub("\n", " ").gsub("\r", " ").truncate(200, ""), #permanent address
                     nil, #state code
                     nil, #client.address_pin, #pin code
                     nil, #client.address.gsub("\n", " ").gsub("\r", " ").truncate(200, ""), #present address
                     nil, #state code
                     nil, #client.address_pin, #pin code
                     nil, #dummy reserved for future use
                     client.id.to_s.truncate(100, ""), #parent id
                     nil, #extraction field id
                     nil #severity
                    ],
        "ACTCRD" => [client.id.to_s.truncate(100, ""),
                     "ACTCRD",
                     loan.id.to_s.truncate(35, ""),
                     loan.id.to_s.truncate(35, ""),
                     branch.id.to_s.truncate(30, ""),
                     client.center_id.to_s.truncate(30, ""),
                     loan.applied_by.name.truncate(30, ""),
                     ((loan.status(@to_date) == :repaid || loan.status(@to_date) == :written_off || loan.status(@to_date) == :preclosed) ? loan.loan_history.last.date.strftime("%d%m%Y") : @to_date.strftime("%d%m%Y").truncate(8,"")), #date of account information
                     loan_category[:jlg_individual].truncate(3, ""), #loan category
                     client.client_group_id.to_s.truncate(20, ""),
                     loan.cycle_number.to_s.truncate(30, ""),
                     (loan.occupation ? loan.occupation.name.truncate(20, "") : nil),  #purpose
                     account_status[loan.get_status],
                     (loan.applied_on ? loan.applied_on.strftime("%d%m%Y").truncate(8, "") : nil),
                     (loan.approved_on ? loan.approved_on.strftime("%d%m%Y").truncate(8, "") : nil),
                     (loan.disbursal_date.nil? ? loan.scheduled_disbursal_date : loan.disbursal_date).strftime("%d%m%Y").truncate(8, ""),
                     ( ( (loan.status == :repaid and loan_history.status == :repaid) || (loan.status == :preclosed and loan_history.status == :preclosed) || (loan.status == :claim_settlement and loan_history.status == :claim_settlement) ) ? loan_history.date.strftime("%d%m%Y").truncate(8, "") : nil), #loan closed
                     loan_history.date.strftime("%d%m%Y").truncate(8, ""), #loan closed
                     (loan.amount_applied_for ? loan.amount_applied_for.to_i.to_s.truncate(9, "") : nil),
                     (loan.amount_sanctioned ? loan.amount_sanctioned.to_i.to_s.truncate(9, "") : nil), #amount approved or sanctioned
                     loan.amount.to_i.to_s.truncate(9, ""), #amount disbursed
                     loan.number_of_installments.to_s.truncate(3, ""), #number of installments
                     repayment_frequency[loan.installment_frequency], #repayment frequency
                     ((loan.scheduled_principal_for_installment(1) + loan.scheduled_interest_for_installment(1)).to_i.to_s.truncate(9, "")),   #installment amount / minimum amount due
                     loan_history.actual_outstanding_total.to_i.to_s.truncate(9, ""),
                     (((loan_history.actual_outstanding_total - loan_history.scheduled_outstanding_total) > 0) ? (loan_history.actual_outstanding_total - loan_history.scheduled_outstanding_total).to_i.to_s.truncate(9, "") : 0), #amount overdue
                     (loan_history.days_overdue > 999 ? 999 : loan_history.days_overdue).to_s.truncate(3, ""), #days past due
                     (loan_history.status == :written_off ? actual_outstanding_principal.to_i.to_s : nil), #write off amount
                     (loan.written_off_on.nil? ? nil : loan.written_off_on.strftime("%d%m%Y").truncate(8, "")), #date written off
                     nil, #write-off reason
                     attendance_record[center.id][client.id], #Attendance.all(:client_id => client.id, :center_id => center.id).count.to_s.truncate(3, ""), #no of meetings held
                     absent_record[center.id][client.id], #Attendance.all(:client_id => client.id, :center_id => center.id, :status => "absent").count.to_s.truncate(3, ""), #no of meetings missed
                     insurance_indicator[(not loan.insurance_policy.nil?)], #insurance indicator
                     nil, #type of insurance
                     (loan.insurance_policy.nil? ? nil : loan.insurance_policy.premium.to_i.to_s.truncate(10, "")), #sum assured / coverage
                     meeting_day_of_the_week[center.meeting_day].to_s.truncate(3, ""), #meeting day of the week
                     center.meeting_time.truncate(5, ""), #meeting time of the day
                     nil, #dummy reserved for future use
                     nil, #old member code
                     nil, #old member shrt number
                     nil, #old account number
                     nil, # cibil act status
                     nil, # asset classification
                     nil, # member code
                     nil, # member shrt number
                     nil, # account type
                     nil, #ownership indicator
                     client.id.to_s.truncate(100, ""), #parent id
                     nil, # extraction field id
                     nil  # severity
                    ]
      }
    end
    
    # specifications as required by the common data format    
    def gender
      _gender ||= {
        :female   => "F", 
        :male     => "M", 
        :untagged => "U"
      }
    end
    
    def marital_status
      _marital_status ||= {
        :married   => "M01", 
        :separated => "M02", 
        :divorced  => "M03", 
        :widowed   => "M04", 
        :unmarried => "M05", 
        :untagged  => "M06"
      }
    end
    
    def key_person_relationship(client, relationship)
      _key_person_relationship ||= {
        'father'          => "K01",
        'husband'         => "K02",
        'mother'          => "K03",
        'son'             => "K04",
        'adult_son'       => "K04",
        'daughter'        => "K05",
        'wife'            => "K06",
        'brother'         => "K07",
        'mother_in_law'   => "K08",
        'father_in_law'   => "K09",
        'daughter_in_law' => "K10",
        'sister_in_law'   => "K11",
        'son_in_law'      => "K12",
        'brother_in_law'  => "K13",
        'other'           => "K15",
      }   
      #if relationship == 'spouse'
      #  return (client.gender == "female" ? _key_person_relationship['husband'] : _key_person_relationship['wife'])
      #else
      #  return _key_person_relationship[relationship]
      #end
    end
    
    def phone
      _phone ||= {
        :residence => "P01",
        :company   => "P02",
        :mobile    => "P03",
        :permanent => "P04",
        :other     => "P07",
        :untagged  => "P08"
      }
    end
    
    def asset_ownership_indicator
      _asset_ownership_indicator ||= {
        :yes => "Y",
        :no  => "N"
      }
    end
    
    def religion
      _religion ||= {
        'hindu'       => "R01",
        'muslim'      => "R02",
        'christian'   => "R03",
        'sikh'        => "R04",
        'buddhist'    => "R05",
        'jain'        => "R06",
        'bahai'       => "R07",
        'others'      => "R08",
        ''            => "R09"
      }
    end
    
    
    def group_leader_indicator
      _group_leader_indicator ||= {
        :yes      => "Y",
        :no       => "N",
        :untagged => "U"
      }
    end
    
    def center_leader_indicator
      _center_leader_indicator ||= {
        :yes      => "Y",
        :no       => "N",
        :untagged => "U"
      }
    end
    
    def loan_category
      _loan_category ||= {
        :jlg_group      => "T01",
        :jlg_individual => "T02",
        :individual     => "T03"
      }
    end
    
    # account status is nothing but loan status
    def account_status
      _account_status ||= {
        :applied_in_future => "S01", #loan submitted
        :pending_approval  => "S01", #loan submitted
        :approved          => "S02", #loan_approved_not_yet_disbursed
        :rejected          => "S03", #loan_declined
        :disbursed         => "S04", #current
        :outstanding       => "S04", #current
        :delinquent        => "S05", #delinquent
        :written_off       => "S06", #written_off
        :claim_settlement  => "S07", #account_closed for intellecash
        :repaid            => "S07", #account_closed
        :preclosed         => "S07"  #account_closed
      }
    end
    
    def repayment_frequency
      _repayment_frequency ||= {
        :weekly              => "F01",  
        :biweekly            => "F02",
        :monthly             => "F03",
        :bimonthly           => "F04",
        :quarterly           => "F05",
        :semi_annually       => "F06",
        :annually            => "F07",
        :single_payment_loan => "F08",
        :other               => "F10",
        :quadweekly          => "F10"
      } 
    end
    
    def write_off_reason
      _write_off_reason = { 
        :first_payment_default             => "X01",
        :death                             => "X02",
        :willful_default_status            => "X03",
        :suit_filed_willful_default_status => "X04", 
        :untagged                          => "X09",
        :not_applicable                    => "X10"
      }
    end
    
    def days_past_due
      _days_past_due ||= {
        :zero_payments_past_due => "000",
        :no_payment_history_available_for_this_month => "XXX",
      }
    end
    
    def insurance_indicator
      _insurance_indicator ||= {
        true      => "Y",
        false     => "N"
      }
    end
    
    def type_of_insurance
      _type_of_insurance ||= {
        :life_insurance            => "L01", 
        :credit_insurance          => "L02",
        :health_medical_insurance  => "L03",
        :property_insurance        => "L04",
        :liability_insurance       => "L05",
        :other                     => "L10"
      }
    end
    
    def meeting_day_of_the_week
      _meeting_day_of_the_week ||= {
        :monday     => "MON",
        :tuesday    => "TUE",
        :wednesday  => "WED",
        :thursday   => "THU",
        :friday     => "FRI",
        :saturday   => "SAT",
        :sunday     => "SUN"
      }
    end
    
    def states
      _states ||= {
        :andhra_pradesh     => "AP",
        :arunachal_pradesh  => "AR",
        :assam              => "AS",
        :bihar              => "BR",
        :chattisgarh        => "CG",
        :goa                => "GA",
        :gujarat            => "GJ",
        :haryana            => "HR",
        :himachal_pradesh   => "HP",
        :jammu_kashmir      => "JK",
        :jharkhand          => "JH",
        :karnataka          => "KA",
        :kerala             => "KL",
        :madhya_pradesh     => "MP",
        :maharashtra        => "MH",
        :manipur            => "MN",
        :meghalaya          => "ML",
        :mizoram            => "MZ",
        :nagaland           => "NL",
        :orissa             => "OR",
        :punjab             => "PB",
        :rajasthan          => "RJ",
        :sikkim             => "SK",
        :tamil_nadu         => "TN",
        :tripura            => "TR",
        :uttarakhand        => "UK",
        :uttar_pradesh      => "UP",
        :west_bengal        => "WB",
        :andaman_nicobar    => "AN",
        :chandigarh         => "CH",
        :dadra_nagar_haveli => "DN",
        :daman_diu          => "DD",
        :delhi              => "DL",
        :lakshadweep        => "LD",
        :pondicherry        => "PY"
      }
    end
  end
#end
