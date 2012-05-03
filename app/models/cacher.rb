class Cacher
  # This class interfaces with memcached to return the appropriate cache, populating the cache if required

  # Provides the requested report from the cache, creating it if it doesn't exist or explicitly requested
  # params is a Hash with the following keys:
  # branch_id => Integer. the requested branch. If present and center_id is absent, will return report grouped by branches centers
  # center_id => Integer. if present, will respond with the individual loans in the center aggregated over the given dates
  # from_date => Date
  # to_date => Date
  # force => Boolean. When true forces cahce invalidation and refreshing
  
  def self.get(params)
    params = params.map{|k,v| [k.to_sym, v]}.to_hash
    cache_key = params.only(:branch_id, :center_id, :from_date, :to_date)
    @cache = DC.get(cache_key)
    # do we recalc?
    recalc = !params[:force].blank? || !@cache
    return @cache unless recalc
    # recalc!
    DC.delete(cache_key)
    @cachers = LoanHistory.get_aggregate_report(params)
    # update the cache
    @cache = {:report => @cachers, :created_at => DateTime.now}
    DC.set(cache_key, @cache)
    @cache
  end

end

