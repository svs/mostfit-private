# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'development')


namespace :mostfit do
  namespace :data do
    desc "loads yml files from spec/fixtures"
    task :fixtures do
      repository.adapter.execute("truncate table memberships")
      repository.adapter.execute("truncate table loan_history")
      [StaffMember, RepaymentStyle, LoanProduct, Funder, FundingLine, Branch, Center, Client, Loan].each do |t|
        p = t.to_s.snake_case.pluralize
        puts "loading #{p}"
        repository.adapter.execute("truncate table #{p}")
        d = YAML::load_file(File.join Merb.root, "spec", "fixtures", "#{p}.yml")
        d.map do |k,v| 
          i = t.create(v) 
          unless i.valid?
            i.errors.each{|e| puts e}
          end
        end
      end
    end
  end
end
