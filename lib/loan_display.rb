module LoanDisplay
  
  # All the stuff the loan needs to know to display itself
  # these are just some defaults. override at will

  def self.display_name
    "Loan"
  end


  def name
    "Loan #{id} "
  end

  def description
    "#{id}:Rs. #{amount} @ #{interest_rate} for client #{client.name}"
  end

  def short_tag
    "#{id}:Rs. #{amount} @ #{interest_rate}"
  end

  def self.description
    "This is the description of the build-in master loan type. Typically you only deal with loan that are derived of this loan type."
  end

  def description
    "#{amount} @ #{interest_percentage}%"
  end


  def to_s
    id.to_s
  end


  def _show_his(keys = nil, width = 8, padding = 2)
    # pretty prints the loan history
    # get extended info by saying _show_his(:extended)
    hist = calculate_history.sort_by{|x| x[:date]}
    unless keys.class == Array
      keys = ReportFormat.get(report_format_id).keys rescue [:scheduled_outstanding_total, :scheduled_outstanding_principal,
                                                             :actual_outstanding_total   , :actual_outstanding_principal,    :actual_outstanding_interest,
                                                             :principal_due, :interest_due, :principal_due_today, :interest_due_today,
                                                             :principal_paid,  :interest_paid]
    end
    puts keys.map{|t| t.to_s.rjust(width - padding/2).ljust(width)}.join("|")
    hist.each do |h|
      puts (["#{h[:date]}"] + keys.map{|t| (h[t.to_sym] || 0).round(2)}.map{|v| v.to_s}.map{|s| s.rjust(width - padding/2).ljust(width)}).join("|")
    end
    false
    #table hist, :fields => keys
  end



end
