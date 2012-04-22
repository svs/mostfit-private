class Cachers < Application

  before :parse_dates

  def index
    # @date ||= Date.today
    # @from_date = @to_date = @date
    # @report_format = ReportFormat.get(params[:report_format]) || ReportFormat.first
    # if @report_format
    #   get_cachers
    #   @keys = [:date] + @keys
    #   display @cachers
    # else
    #   redirect(resource(:report_formats), :message => {:error => "Could not generate Caches as no Report formats were found. Create one to generate Caches"})
    # end
    redirect url(:live_cachers)
  end

  def missing
    params[:stale] = true
    get_cachers
    display @cachers, :template => 'cachers/index'
  end
  
  # attempts to do the same as consolidate
  # but without using cachers. direct queries from the database
  def live
    debugger
    @t = Time.now
    @group_by = params[:branch_id].blank? ? :branch_id : (params[:center_id].blank? ? :center_id : :loan_id)
    gb = @group_by
    lh = DB[:loan_history].filter(params.only(:branch_id, :center_id).select{|k,v| !v.blank?}.to_hash)
    @report_format = ReportFormat.get(params[:report_format]) || ReportFormat.first
    td = @to_date
    cache_key = params.except(:layout, :report_format)
    @cache = DC.get(cache_key)
    recalc = !params[:force].blank? || !@cache
    unless recalc
      @cachers = @cache[:cachers]
    else
      flow_sum = lh.filter(:date => @from_date..@to_date).select(*([gb] + (Cacher::FLOW_COLS).map{|c| :sum[c]})).group_by(gb)
      flow_sum = flow_sum.all.map{|x| [x[gb], x]}.to_hash
      bal_keys = lh.group_by(:loan_id).filter{ date < td }.select_map(:max[:composite_key])
      bal_sum = lh.filter(:composite_key => bal_keys).select(*([gb] + (Cacher::COLS).map{|c| :sum[c]})).group_by(gb)
      bal_sum = bal_sum.all.map{|x| [x[gb], x]}.to_hash
      @cachers = bal_sum + flow_sum
      @cache = {:cachers => @cachers, :created_at => DateTime.now}
      DC.set(cache_key, @cache)
    end
    @group_object = @group_by.to_s.split('_')[0].pluralize.to_sym
    debugger
    if @group_object == :loans
      @group_by_names = DB[@group_object].filter(:id => @cachers.keys).to_hash(:id, :id) rescue {}
    else
      @group_by_names = DB[@group_object].filter(:id => @cachers.keys).to_hash(:id, :name) rescue {}
    end
    render 
  end

  def generate
    @model = params[:by] ? Kernel.const_get(params[:by].camel_case + "Cache") : BranchCache
    if @from_date and @to_date
      (@from_date..@to_date).each{|date| @model.update(:date => date)}
    else
      @model.update(:date => (@date || Date.today))
      if Branch.count > 0
        if @from_date and @to_date
          (@from_date..@to_date).each{|date| BranchCache.update(:date => date)}
        else
          BranchCache.update(:date => (@date || Date.today))
        end
        redirect request.referer
      else
        redirect url(:browse, :action => 'index'), :message => {:error => "No data found to generate report"}
      end
    end
  end

  def update
    BranchCache.update(@date)
    redirect resource(:cachers, :date => @date)
  end

  def recreate
    BranchCache.recreate(@date)
    redirect resource(:cachers, :date => @date)
  end


  # puts stale branch caches in a queue for recalculation
  def freshen
  end

  def consolidate
    get_cachers
    group_by = @level.to_s.singularize
    group_by_model = Kernel.const_get(group_by.camelcase) rescue Kernel.const_get(params[:by].camel_case)
    unless group_by == "loan"
      @cachers = @cachers.group_by{|c| c.send("#{group_by}_id".to_sym)}.to_hash.map do |group_by_id, cachers| 
        # when we are aggregating "by" something else we need to consolidate cachers that span across dates and 
        # add cachers for the same date
        if params[:by]
          cachers_for_date = cachers.group_by{|c| c.date}.to_hash.map{|d, cs| [d,cs.reduce(:+)]}.to_hash
          r = cachers_for_date.values.reduce(:consolidate)
          r.model_id = group_by_id
          r.branch_id = nil
          r
        else
          cachers.reduce(:consolidate)
        end
      end
    end
    display @cachers, :template => 'cachers/index', :layout => (params[:layout] or Nothing).to_sym
  end

  def split
    get_cachers
    @cachers =  @center ? @cachers.all(:center_id => @center.id) : @cachers.all(:center_id => 0)
    display @cachers, :template => 'cachers/index'
  end

  # recalculates loan history and regenerates the cache for a center
  #
  # params => {:center_id => x}
  def rebuild
    @center = Center.get(params[:center_id])
    raise NotFound unless @center
    CenterCache.stalify(:center_id => params[:center_id], :date => (@date || @center.creation_date))
    @center.loans.each{|l| l.update_history}
    BranchCache.update(@date, @center.branch.id)
    redirect request.referer, :message => {:notice => 'Rebuilt caches for today. Marked caches after today as stale. They will be rebuilt upon request'}
  end

  def reallocate
    @center = Center.get(params[:center_id])
    raise NotFound unless @center
    @loans = params[:loan_ids].blank? ? @center.loans.select{|l| l.status == :outstanding} : Loan.all(:id => params[:loan_ids].keys.map(&:to_i)) 
    CenterCache.stalify(:center_id => params[:center_id], :date => (@date || @center.creation_date))
    only_schedule_mismatches = (not params[:only_mismatches].blank?)
    @loans.each{|l| l.reallocate(params[:style].to_sym, session.user, nil, only_schedule_mismatches)}
    BranchCache.update(@date, @center.branch.id)
    redirect request.referer, :message => {:notice => 'Reallocated all loans. Marked caches after today as stale. They will be rebuilt upon request'}
  end

  private
  
  def parse_dates
    {:date => Date.today, :from_date => Date.today - 7, :to_date => Date.today}.each do |date, default|
      instance_variable_set("@#{date.to_s}", (params[date] ? (params[date].is_a?(Hash) ? Date.new(params[date][:year].to_i, params[date][:month].to_i, params[date][:day].to_i) : Date.parse(params[date])) : default))
    end
  end


  def get_cachers
    q = {}
    q[:branch_id] = params[:branch_id] unless params[:branch_id].blank? 
    unless params[:branch_id].blank?
      if params[:center_id]
        q[:center_id] = params[:center_id] unless (params[:center_id].blank? or params[:center_id].to_i == 0)
      else
        q[:center_id.not] = 0
      end
    else
      if params[:by]
        q[:model_name] = params[:by].camel_case
        q[:center_id] ||= 0 unless q[:center_id.not]
        q[:model_id] = params[:model_id] if params[:model_id]
      else
        q[:model_name] = ["Branch"]# + ,"Center"] 
      end
    end
    q[:date] = @date if @date
    q[:date] = @from_date..@to_date if (@from_date and @to_date)
    q[:stale] = true if params[:stale]
    @cachers = Cacher.all(q)
    q.delete(:model_name)
    if params[:by]
      @missing_centers = {} # TODO
    else
      @missing_centers = {} #CenterCache.missing(q)
    end
    get_context
  end

  def get_context
    @center = params[:center_id].blank? ? nil : Center.get(params[:center_id])
    @branch = params[:branch_id].blank? ? nil : Branch.get(params[:branch_id])
    @area = params[:area_id].blank? ? nil : Area.get(params[:area_id])
    @region = params[:region_id].blank? ? nil : Region.get(params[:region_id])
    @center_names = @cachers.blank? ? {} : Center.all(:id => @cachers.aggregate(:center_id)).aggregate(:id, :name).to_hash
    @branch_names = @cachers.blank? ? {} : Branch.all(:id => @cachers.aggregate(:branch_id)).aggregate(:id, :name).to_hash
    q = (@from_date and @to_date) ? {:date => @from_date..@to_date} : {:date => @date}
    @stale_centers = Cacher.all(q.merge(:stale => true))
    @stale_branches = BranchCache.all(q.merge(:stale => true))
    @last_cache_update = @cachers.aggregate(:updated_at.min)
    @resource = params[:action] == "index" ? :cachers : (params[:action].to_s + "_" + "cachers").to_sym
    @keys = [:branch_id, :center_id] + (ReportFormat.get(params[:report_format]) || ReportFormat.first).keys
    @total_keys = @keys[2..-1]
    if @resource == :split_cachers
      @level = (params[:center_id].blank? ? :branches : :centers)
      @keys = [:date] + @keys
    else 
      @level = @center ? :loans : (@branch ? :centers : (@area ? :branches : (@region ? :areas : :branches)))
      if params[:by]
        @level = :model unless @level == :loans
        @keys = [:model_name] + @keys
        @model = Kernel.const_get(params[:by].camel_case)
      else
      end
    end
  end

end
