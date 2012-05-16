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
    task :convert_sahayog, :start_id, :end_id do |task, args|
      already_done = File.read("log/upgrade-#{args[:start_id]}").split("\n").map(&:to_i) rescue []
      logfile = File.open("log/upgrade-#{args[:start_id]}","w")
      logfile.write "upgrading\n"
      Rake::Task['db:autoupgrade'].invoke
      logfile.write "done\n"
      lids = Loan.all(:id => (args[:start_id].to_i)..(args[:end_id].to_i)).aggregate(:id)
      ct = lids.count
      t = Time.now
      lids.each_with_index do |lid,i|
        next if already_done.include?(lid)
        begin
          logfile.write "#{lid} - #{i}/#{ct}"
          l = Loan.get lid
          c = l.client
          c.center = Center.get(c.center_id)
          # c.gender = :female
          c.save!
          l.send(:set_center)
          l.save
          l.reload
          debugger
          next if l.status != :outstanding
          l.remake_payments
          print ".".green
          logfile.write("(#{Time.now - t} secs)\n")
          logfile.flush
        rescue Exception => e
          debugger
          print ".".red
        end
        print (Time.now - t).round(2)
      end
      logfile.close
    end
  end
end
