class Membership
  include DataMapper::Resource

  # Class to manage the membership of various objects in other objects
  # i.e. Clients in Centers, Loans in Centers, etc.
  # this class is an abstract class and will throw an error should you try to use it
  # To be used, the membership must be subclassed into a MemberClubMembership class i.e. ClientCenterMembership
  # such a naming convention will automatically place Client as the member type and Center as the club type
  # to override this, place class variables as @@member_model and @@club_model to override the default behaviour
  # i.e. if your model has two words in it such as StaffMember

  # P.S. Wow - a whole membership class in 13 LOC? That's some deep understanding of the problem

  #http://railstips.org/blog/archives/2006/11/18/class-and-instance-variables-in-ruby/
  class << self; attr_accessor :allow_overlap end
  @allow_overlap  = true   # allow overlap means to allow overlapping memberships of clients in different centers 
                            # i.e. when allow_overlap is false, client can belong to many centers but only one at a time
  property :id,   Serial
  property :type, Discriminator
  
  property :from, Date, :nullable => false, :default => Date.new(1900,1,1)
  property :upto, Date, :nullable => false, :default => SEP_DATE
  
  
  # Returns the #club_model for the member as of a particular date
  # we can optionally pass in the collection to be examined. This is useful in cases when the collection has not been persisted to the datastore
  def self.as_of(as_of, collection = nil)
    collection ||= self.all
    group_by = @allow_overlap ? :club_id : :type  # i.e. if overlaps are not allowed, we don't do any grouping and basically return the last object
    ans = collection.group_by(&group_by).map do |group_by_id,grouped_memberships|
      _o = grouped_memberships.select{|x| x.from <= as_of and x.upto >= as_of}.sort_by{|x| x.from}
      _o[-1].club_id rescue nil
    end.flatten.compact
    ans = @allow_overlap ? ans : ans.first
  end

end

# to add specific memberships, creating new child classes of Membership as shown below will suffice.
# do also look at Client#center= and Client#center methods to get an idea of how to add getters and setters in the class
# TODO: move getters and setters behind a nice api like so
# class Client
#    ...
#    is_member_of :center, :overlap => true
#    ...
# end

class ClientCenterMembership < Membership
  @allow_overlap = true

  belongs_to :member, :model => 'Client'
  belongs_to :club,   :model => 'Center'

end


class LoanCenterMembership < Membership

  @allow_overlap = false

  belongs_to :member, :model => 'Loan'
  belongs_to :club,   :model => 'Center'

end
