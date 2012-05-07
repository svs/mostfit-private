class Membership
  include DataMapper::Resource

  # Class to manage the membership of various objects in other objects
  # i.e. Clients in Centers, Loans in Centers, etc.

  @@allow_multiple = true   # allow, for example, one client to belong to many centers i.e. client can belong to many centers
  @@allow_overlap  = true   # allow overlap means to allow overlapping memberships of clients in different centers 
                            # i.e. when allow_multiple is true and allow_overlap is false, client can belong to many centers but only one at a time
  @@allow_gaps      = true  # when false, do not allow a period without membership
  @@member_model    = nil   # which model is the member of which model? overridden in base classes
  property :id,   Serial
  property :type, Discriminator
  property :from, Date, :nullable => false, :default => Date.new(1900,1,1)
  property :upto, Date, :nullable => false, :default => SEP_DATE

  validates_with_method :check_dates

  # Returns the #club_model for the member as of a particular date
  def self.as_of(as_of)
    group_by = club_model
    if @@allow_multiple
      ans = self.all.group_by{|x| x.send(group_by)}.map do |group_by_id,grouped_memberships|
        _o = grouped_memberships.select{|x| x.from <= as_of and x.upto >= as_of}.sort_by{|x| x.from}
        _o[-1].send(group_by) rescue nil
      end
      ans.flatten.compact
    end
  end

  # clubs have members so a member must belong to a club. Sorry cou;dn't think of a better name
  # we know which is the member, so the other one is the club
  def self.club_model
    candidates = (properties.select{|p| p.name.to_s =~ /_id/}.map(&:name) - ["#{@@member_model}_id".to_sym])
    raise "oops - you have more than two belongs_to relationships in the #{self} model. This is not allowed" if candidates.size > 1
    candidates[0]
  end



  
  # Private: Returns the query hash to find all the memberships for this entity
  def peer_search_query
    (self.send(:properties).map(&:name) - [:id, :from, :upto, self.model.club_model]).map{|x| [x, self.send(x)]}.to_hash
  end

  # Private: gets all the other memberships i.e. excluding the entity itself for this entity
  def peers
    self.model.all(peer_search_query) - [self]
  end
  
  # given a Collection of Memberships, it tells you whether any of them overlaps datewise with the current object
  def overlap?(memberships)
    memberships.sort_by{|m| m.from}.map{|m| 
      ((self.upto >= m.from and self.upto <= m.upto) or (self.from <= m.upto and self.upto >= m.from))
    }.include?(true)
  end

  def gaps?(memberships)
    false # we need to think about this
  end

  def check_dates
    rv = {}; p = peers
    rv[:empty] = gaps?(p) if !@@allow_gaps
    return true
  end

end


class ClientCenterMembership < Membership
  @@allow_gaps   =  true    # we need to think about this. for the moment - caveat usor!
  @@member_model = :client  # this is the model that seeks membership

  belongs_to :center
  belongs_to :client

end

