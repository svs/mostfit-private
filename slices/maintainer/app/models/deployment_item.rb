class Maintainer::DeploymentItem

  include DataMapper::Resource
  
  property :id,       Serial
  property :sha,      String,   :required => true, :length => 40
  property :message,  Text,     :required => true
  property :time,     DateTime, :required => true
  property :branch,   String,   :required => true, :default => "master"

  def self.create_from_last_commit
    git = Git.open(GIT_REPO)
    DM_REPO.scope {
      Maintainer::DeploymentItem.create(
        :sha     => git.log.first.sha,
        :message => git.log.first.message,
        :time    => Time.now,
        :branch  => git.current_branch
      )
    }
  end
  
end
