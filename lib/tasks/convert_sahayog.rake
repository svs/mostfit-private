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
    desc "convert intellecash db to takeover-intellecash"
    task :convert_sahayog do
      puts "upgrading"
      repository.adapter.execute("truncate table loan_history")
      Rake::Task['db:autoupgrade'].invoke
      puts "done"

      # update the center_meeting_days for specified centers
      dcs = Center.all(:id => [1642,1675,1676,1120,1121,1122,2146,1809,1810])
      dcs.each do |c|
        cmd = CenterMeetingDay.all(:center => c).last
        cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 1)
      end
      cmd = CenterMeetingDay.get(4121)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(3738)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(3740)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 1)
      cmd = CenterMeetingDay.get(828)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_upto => Date.new(2011,8,26))
      cmd = CenterMeetingDay.get(3825)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(3826)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(3827)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(2146)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(3827)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_from => cmd.valid_from + 2)
      cmd = CenterMeetingDay.get(105)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_upto => Date.new(2011,7,20))
      cmd = CenterMeetingDay.get(4001)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_upto => Date.new(2011,7,22))
      cmd = CenterMeetingDay.get(107)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_upto => Date.new(2011,7,20))
      cmd = CenterMeetingDay.get(4002)
      cmd.update(:every => "1", :what => cmd.meeting_day.to_s, :of_every => 1, :period => :week, :valid_upto => Date.new(2011,7,22))

      Rake::Task['mostfit:conversion:to_new_layout'].invoke
    end
  end
end
