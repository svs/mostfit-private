module LoanFiddling
  # this file contains some radical functions to alter loan history.
  # these were mainly used by Sahayog during their conversion of loans from Flat to Reducing Balance
  # these methods are quite dangerous but are also useful, so they go in the LoanFiddling module

  def correct_prepayments
    prins = payments(:type => :principal).sort_by{|p| p.received_on}.reverse
    ints = payments(:type => :interest).sort_by{|p| p.received_on}.reverse
    total = 0
    diff = amount - prins.map{|p| p.amount}.reduce(:+)
    ints.each do |ix|
      transfer = [ix.amount, diff - total].min
      px = prins.find{|_p| _p.received_on == ix.received_on}
      px.amount += transfer
      ix.amount -= transfer
      puts "transferred #{transfer}"
      px.amount = px.amount.round(2)
      ix.amount = ix.amount.round(2)
      total += transfer
      px.save!
      ix.save!
    end
    puts total
    self.update_history
  end


  # if principal and interest have been wrongly allocated, or one has changed the allocation style
  # call this function on the loan and all will be well again
  def reallocate(style, user, date_from = nil, only_schedule_mismatches = false)
    self.extend_loan
    return false unless REPAYMENT_STYLES.include?(style)
    if style == :correct_prepayments
      status, _pmts = correct_prepayments
      return status, _pmts
    end
    _ps  = self.payments(:type => [:principal, :interest])
    ph = _ps.group_by{|p| p.received_on}.to_hash
    _pmts = []
    self.payments_hash([])
    bal = amount
    dates = date_from ? ph.keys.sort.select{|d| d >= date_from} : ph.keys.sort
    # first find the total amount, user etc for each date
    pmt_details = dates.map do |date|
      prins = ph[date].select{|p| p.type == :principal}
      ints = ph[date].select{|p| p.type == :interest}
      p_amt = prins.reduce(0){|s,p| s + p.amount} || 0
      i_amt = ints.reduce(0){|s,p| s + p.amount} || 0
      total_amt = p_amt + i_amt
      ref_payment = (prins[0] ? prins[0] : ints[0])
      user = ref_payment.created_by
      received_by = ref_payment.received_by
      [date, {:total => total_amt, :user => user, :date => date, :received_by => received_by}]
    end.to_hash
    statii = []
    _t = DateTime.now
    # then delete all payments and recalculate a virgin loan_history
    ds = _ps.map{|p| p.deleted_by = user; p.deleted_at = _t; p.save!}
    reload
    update_history
    clear_cache
    # then make the payments again
    pmt_details.keys.sort.each do |date|
      details = pmt_details[date]
      reload
      pmts = repay(details[:total], details[:user], date, details[:received_by], false, style, :reallocate, nil, nil)
      clear_cache
      statii.push(pmts[0])
    end
    self.reload
    update_history(true)
    return true, _pmts
  end
  
  # Takes each interest and principal payment and makes it again.
  # This has been specifically written to split our payments using the new received_on and received_for methodology
  def remake_payments
    debugger
    pmts = payments.all(:type => [:principal, :interest])
    # Payment.transaction do |t|
      debugger
      payments.all.map{|p| p.deleted_at = DateTime.now; p.deleted_by = User.first; p.save!}
      clear_cache
      update_history
      pmts.sort_by{|p| p.received_on}.each do |p|
        repay({p.type => p.amount}, p.created_by, p.received_on, p.received_by, false, nil, :reallocate, nil, nil)
        clear_cache
        update_history
        print "."
      end
    # end
  end
  
end
