class Bookmark
  include DataMapper::Resource
  attr_accessor :url
  #ShareWith = [:none, :all, :admin, :staff_member, :mis_manager, :data_entry, :read_only]

  property :id, Serial
  property :name,            String, :length => 50, :required => true
  property :title,           String, :length => 100, :required => true
  property :route,           Text,   :required => true
  property :type,            Enum.send('[]', *BookmarkTypes), :required => true,   :default => :system, :index => true
  property :method_name,     Enum.send('[]', *MethodNames), :required => false, :default => :get, :index => true
  property :params,          Text,    :required => false
  property :user_id,         Integer, :required => true, :index => true
  property :share_with,      Flag.send('[]', *User::ROLES), :required => true, :default => :none, :index => true
  belongs_to :user
  
  validates_uniqueness_of :name, :with_scope => [:type, :user]

  def self.for(user, type=:system)
    {
      :shared => Bookmark.all(:user.not => user, :type => type).find_all{|b| b.share_with.include?(user.role)},
      :own => Bookmark.all(:user => user, :type => type)
    }
  end

  def self.search(q, user, per_page=10)
    if /^\d+$/.match(q)
      all(:conditions => ["id = ?", q], :limit => per_page, :type => :system).find_all{|b|
        b.share_with.include?(user.role)
      }
    else
      all(:name.like => q+'%', :limit => per_page, :type => :system).find_all{|b|
        b.share_with.include?(user.role)
      }
    end
  end

  def controller
    @url ||= YAML::load(self.route).last
    @url[:controller]
  end

  def action
    @url ||= YAML::load(self.route).last
    @url[:action]
  end

end
