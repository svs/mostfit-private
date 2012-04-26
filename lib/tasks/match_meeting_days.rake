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

    task :mismatched_centers do
      log = File.open("log/mismatch_fix.log","w")
      @biweekly_centers = Loan.all(:installment_frequency => :biweekly).clients.centers.aggregate(:id)
      puts "found #{@biweekly_centers.count} centers."
      @biweekly_centers.each do |cid|
        c = Center.get(cid)
        cmd = c.center_meeting_days.last
        if (cmd.meeting_day == :none and cmd.of_every == 2 and cmd.period == :week) # center is matched
          log.write("#{cid}: ok\n")
          print "#{cid} ".green
        elsif cmd.meeting_day == :none and cmd.period == :week # CMD has :none in meeting_day and a weekday in the :what field
          cmd.of_every = 2                                     # nothing much to do, just make the :of_every = 2
          cmd.save
          log.write "#{c.id}: was none. fixed!\n"
          print "#{cid} ".red
        elsif cmd.meeting_day != :none and cmd.period == :week # CMD already has a weekly meeting day  
          cmd.what = cmd.meeting_day                           # set the :what to this day
          cmd.of_every = 2                                     # set the frequency to 2
          cmd.meeting_day = :none                              # remove the weekly meeting day
          cmd.save
          log.write "#{c.id}: was #{cmd.what}. fixed!\n"
          print "#{cid} ".yellow
        end
      end
      @monthly_centers = Loan.all(:installment_frequency => :monthly).clients.centers.aggregate(:id)
      puts "found #{@monthly_centers.count} centers."
      @monthly_centers.each do |cid|
        c = Center.get(cid)
        cmd = c.center_meeting_days.last
        unless cmd
          log.write("#{cid}: NO CMD!!!!")
          next
        end
        if (cmd.meeting_day == :none and cmd.of_every == 1 and cmd.period == :month) # center is matched
          log.write("#{cid}: ok\n")
          print "#{cid} ".green
        elsif cmd.meeting_day == :none and cmd.period == :week  # CMD has :none in meeting_day (as we require) and a weekday in the :what field
          l = c.loans.last                                      # get an arbitrary loan
          unless l
            log.write("#{cid}: NO LOANS!!!!")
            next
          end
          d = l.scheduled_first_payment_date.day                # find the day on which it pays
          cmd.every = [d]                                       # adjust the CMD accrodingly
          cmd.what = :day
          cmd.of_every = 1                                      
          cmd.period = :month
          cmd.save
          log.write "#{c.id}: was none. fixed!\n"
          print "#{cid} ".red
        elsif cmd.meeting_day != :none and cmd.period == :week # CMD already has a weekly meeting day  
          l = c.loans.last
          d = l.scheduled_first_payment_date.day  
          cmd.every = [d]
          cmd.what = :day                                      
          cmd.of_every = 1                                     
          cmd.meeting_day = :none                              
          cmd.period = :month
          cmd.save
          log.write "#{c.id}: was #{cmd.what}. fixed!\n"
          print "#{cid} ".yellow
        end
      end

    end

  end
end

