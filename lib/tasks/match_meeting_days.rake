require "rubygems"

# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"
require "colored"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'development')

namespace :mostfit do
  namespace :tmp do
    task :match_meeting_days, :center_id do |task, args|
      if args[:center_id]
        cids = CenterMeetingDay.all(:of_every => 2, :period => :week, :center_id.gt => args[:center_id].to_i).aggregate(:center_id)
      else
        cids = CenterMeetingDay.all(:of_every => 2, :period => :week).aggregate(:center_id)
      end
      cids.each do |cid|
        begin
          c = Center.get(cid)
          l = c.loans.last
          unless l
            print "#{cid} ".yellow
            next
          end
          d = l.scheduled_first_payment_date
          cmds = c.get_meeting_dates(10, d-30)
          if !cmds.include?(d)
            if c.center_meeting_days(:valid_upto.lt => d).count > 0
              print "#{cid} ".red
            else
              print "#{cid} ".green
              cmd = c.center_meeting_days.first
              if cmd.update(:valid_from => cmd.valid_from - 7)
                c.loans.each do |_l|
                  _l.update_history
                  print ".".green
                end
                print "!".green
              end
            end
          end
        rescue
          puts "  #{cid}  ".yellow
        end
      end
    end
  end
end

