# TODO - 
#  DONE - Move Keys/PWs to config and ENV vars
#  Setup DockerFile
#  Setup options
#  DONE - Setup LDAP fields
#  Setup user aggregation/merge
#  STARTED - REFACTOR the living shit out this
#  Setup RSPEC
#  Get code coverage to 100%
#  Rubocop it
#  Setup logging
#  Setup error handling!!!!
#  DONE - Get this into Gitlab!!!
#  Setup in pipeline
#  DONE - Setup "Eligibility" logic!!!
#  DONE - Setup better XML builder/template writer
#  STARTED - Clean up your config setup - it's a bit unruly right now
#  Eventually move to Gitlab/Lap
#  DONE - switch to use JSON for all data collection (UCPath/SIS/Alma)

# STEPS:
#  1 - Get List of Users 
#      (either Change Log or full list if doing a full Sync)
#  2 - Go through list:
#    COLLECT DATA:
#    A - Get UCPath Record
#    B - Get LDAP Record
#    C - Get ALMA Record
#    AGGREGATE:
#    D - Create an Alma User Object
#    E - If Alma rec exists check for differences and merge
#    MUNGE:
#    F - Set roles, handle purges, etc...
#    G - Generate XML Fragment (for individual user record)
#    H - Add fragment to XML Doc (for collection)
#  3 - Save XML file
#  4 - Zip file
#  5 - Send XML file to ??? (where Ex Libris collects files for sync/update)
#      FTP to: upload.lib.berkeley.edu/alma/
#                                           patron_employees
#                                           patron_students
#
#   Allow add-hoc runs (Specific date ranges? Specific user IDs?)


require 'getoptlong'

require_relative 'config/config'
require_relative 'lib/alma'
require_relative 'lib/ldap'
require_relative 'lib/sis'
require_relative 'lib/ucpath'

# Include your modules
include Alma
include LDAP
include UCPath


# TODO - Set up options, build help menu!
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--type', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--changelog', GetoptLong::NO_ARGUMENT ],
)

opts.each do |opt, arg|
  case opt
    when '--help'
      puts "\n\nruby alma_user_load.rb -t <sis|ucpath>"
      exit
    when '--type'
      @type = arg
    when '--outfile'
      @outfile = arg
    when '--checklinks'
      @checklinks = true
    when '--nofft'
      # global since this is checked in ohc_to_xml.rb module
      $nofft = true
  end
end

if @type == 'ucpath'
  puts "Processing UCPath..."
  
  # FETCH THE CHANGE LOG
  change_log = UCPath::User.fetch_change_log
  
  user_list = []


  if change_log
    change_log.each do |id|
      puts "\tFetching ID: #{id}"
      u = UCPath::User.new(id)
      
      if u.is_eligible?
        user_list.push(u)
      else
        # LOG THE FAILURE - who...why
      end
    end

    # BUILD XML
    builder = Alma::XMLBuilder.new user_list

    puts "---------- alma_user_load | line# 107 ------------"
    puts "builder : #{builder.doc.to_xml}"
    puts "--------------------------------------"

    # To Print XML File:
    # f = File.open("user_uploads.xml", "w")
    # f.write(builder.doc.to_xml)
    # f.close
  else
    # Log this? Error? Should we ALWAYS expect some recs?
    puts "\n\nWARNING - No Records Found\n\n"
  end

  

elsif @type == 'sis'
  # RUN SIS... well eventually, someday, when those SIS folks get off their butts and give access!
  puts "----->SIS"
  puts "one big todo list at this point!\n\n"
elsif @type == 'alma'
  # Quick and dirty ALMA API Testing
  puts "----->ALMA"
  alma_user = Alma::API.fetch_alma_user('10335026')
  puts "---------- alma_user_load | line# 140 ------------"
  puts "user.inspect : #{alma_user.inspect}"
  puts "--------------------------------------"
elsif @type == 'ldap'
  # Quick and dirty test of LDAP
  puts "\n\n----->TESTING LDAP"
  LDAP::API.fetch_ldap_rec('1707532')
else
  puts "\nERROR: type is required and must be 'sis' or 'ucpath'\n"
  exit
end

if @changelog
  puts "---------->fetching change log..."

end

