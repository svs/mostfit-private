require "rubygems"

# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'production')

namespace :mostfit do
  namespace :conversion do
    desc "adds centers to clients and loans"
    task :add_centers do 
      @uncentered_loans = Loan.all.aggregate(:id) - LoanCenterMembership.all.aggregate(:member_id)
      total = @uncentered_loans.count
      puts "Found total #{total} loans without centers on them"
      @uncentered_loans.each_with_index do |lid,i|
        l = Loan.get lid
        c = l.client
        c.center = Center.get(c.center_id)
        # c.gender = :female
        c.save!
        l.send(:set_center)
        l.save!
        print "."
        if i%50 == 0
          puts "#{i}/#{total}"
        end
      end
    end
    
    desc "makes all payments again in order to split them into normal, advance or overdue. DOES NOT REALLOCATE"
    task :remake_payments, :branch_id do |task, args|
      lids = Payment.all(:received_for => nil).aggregate(:loan_id)
      ct = lids.count
      t = Time.now
      lids.each_with_index do |lid,i|
        next if already_done.include?(lid)
        begin
          logfile.write "#{lid} - #{i}/#{ct}"
          l = Loan.get lid
          next if l.status != :outstanding
          l.remake_payments
          print ".".green
          logfile.write("(#{Time.now - t} secs)\n")
          logfile.flush
        rescue Exception => e
	  logfile.write("failed!\n")
          logfile.flush
          print ".".red
        end
        print (Time.now - t).round(2)
      end
      logfile.close
    end
  end
end
