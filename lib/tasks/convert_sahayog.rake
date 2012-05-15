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
    desc "upgrade sahayog"
    task :convert_sahayog do
      puts "upgrading"
      Rake::Task['db:autoupgrade'].invoke
      puts "done"
      lids = Loan.all.aggregate(:id)
      c = lids.count
      t = Time.now
      lids.each_with_index do |lid,i|
        begin
          puts "#{lid} - #{i}/#{c}"
          l = Loan.get lid
          c = l.client
          c.center = Center.get(c.center_id)
          c.gender = :female
          c.save
          l.set_center
          l.save
          l.remake_payments
          print ".".green
        rescue
          print ".".red
        end
        print (Time.now - t).round(2)
      end
    end
  end
end
