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

  
  # attempts to do the same as consolidate
  # but without using cachers. direct queries from the database
  def live
    @t = Time.now
    @group_by = params[:branch_id].blank? ? :branch_id : (params[:center_id].blank? ? :center_id : :loan_id)
    @report_format = ReportFormat.get(params[:report_format]) || ReportFormat.first
    key = {"from_date" => @from_date, "to_date" => @to_date}.merge(params)
    @cache = Cacher.get(key)
    @cachers = @cache[:report]
    # massage the data for presentation
    @group_object = @group_by.to_s.split('_')[0].pluralize.to_sym
    if @group_object == :loans
      @group_by_names = DB[@group_object].filter(:id => @cachers.keys).to_hash(:id, :id) rescue {}
    else
      @group_by_names = DB[@group_object].filter(:id => @cachers.keys).to_hash(:id, :name) rescue {}
    end
    render 
  end


  private
  
  def parse_dates
    {:date => Date.today, :from_date => Date.today - 7, :to_date => Date.today}.each do |date, default|
      instance_variable_set("@#{date.to_s}", (params[date] ? (params[date].is_a?(Hash) ? Date.new(params[date][:year].to_i, params[date][:month].to_i, params[date][:day].to_i) : Date.parse(params[date])) : default))
    end
  end



end
