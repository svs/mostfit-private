class PortfolioLoan
  include DataMapper::Resource

  property :id,             Serial
  property :loan_id,        Integer, :index => true, :required => true
  property :portfolio_id,   Integer, :index => true, :required => true
  property :original_value, Integer, :index => true, :required => true
  property :starting_value, Integer, :index => true, :required => true
  property :current_value,  Integer, :index => true, :required => true

  property :added_on,       Date, :index => true, :default => Date.today, :required => true
  property :active,         Boolean, :index => true, :default => true, :required => true

  belongs_to :portfolio
  belongs_to :loan

end
