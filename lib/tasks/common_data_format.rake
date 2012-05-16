require "rubygems"

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

  namespace :highmark do

    desc "This rake task generates the Common Data Format for integration with Highmark"
    task :generate, :to_date, :from_date do |t, args|
      if args[:to_date].nil?
        puts
        puts "USAGE: rake mostfit:highmark:generate[<to_date>,<from_date>]"
        puts
        puts "NOTE: Make sure there are no spaces after and before the comma separating the two arguments." 
        puts "      The to_date has to be supplied. If the from_date is not supplied it is assumed to be three months previous to the to_date."
        puts "      The format for the date is DD-MM-YYYY. The date has to be enclosed in single quotes. For 6th August 2011 it shall be '06-08-2011'."
        puts
        puts "EXAMPLE: rake mostfit:highmark:generate['13-07-2011']"
        puts "         rake mostfit:highmark:generate['13-07-2011','06-07-2011']"
      else
        to_date = Date.strptime(args[:to_date], "%d-%m-%Y")
        from_date = args[:from_date].nil? ? nil : Date.strptime(args[:from_date], "%d-%m-%Y")
        t1 = Time.now
        report = CommonDataFormat.new({}, {:to_date => to_date, :from_date => from_date}, User.first)
        data = report.generate
        folder = File.join(Merb.root, "doc", "csv", "reports")      
        FileUtils.mkdir_p(folder)
        filename1 = File.join(folder, "#{report.name}-customer.csv")
        filename2 = File.join(folder, "#{report.name}-address.csv")
        filename3 = File.join(folder, "#{report.name}-accounts.csv")
        file1 = report.get_csv(data["CNSCRD"], filename1)
        file2 = report.get_csv(data["ADRCRD"], filename2)
        file3 = report.get_csv(data["ACTCRD"], filename3)
        t2 = Time.now
        puts
        puts "It took #{t2-t1} seconds to generate this report."
        puts "The files are stored at #{folder}"
      end
    end

  end

end
