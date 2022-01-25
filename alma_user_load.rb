# TODO - 
#  Verify I have all "required" fields for eligibility
#  STARTED - Setup options
#  STARTED - REFACTOR the living shit out this
#  STARTED - Setup logging (guess do a csv file per run... )
#  STARTED - Clean up your config setup - it's a bit unruly right now
#  Setup error handling!!!!
#  Setup RSPEC
#  Get code coverage to 100%
#  Rubocop it (ugh... dred!)
#  Move to Gitlab/Lap
#  Setup DockerFile
#  Setup in pipeline
#  Setup transfer of zip file to Ex Libris
#  Setup full user base (if we want that...sounds scary)
#  Write up README
#  Go through the million "TODOs" littered through all this code!
#  Eventually build out custom logger (CSV of each record touched, each event and outcome)
#  DONE - Workout the address start/end dates - it's unclear what they should be (Becky is working on this)
#  DONE - Make file naming convention dynamic? (add date, type, etc...)
#  DONE - Move Keys/PWs to config and ENV vars
#  DONE - Setup LDAP fields
#  DONE - Setup user aggregation/merge
#  DONE - Get this into Gitlab!!!
#  DONE - Setup "Eligibility" logic!!!
#  DONE - Setup better XML builder/template writer
#  DONE - switch to use JSON for all data collection (UCPath/SIS/Alma)
#  DONE - Setup to zip the xml file
#  DONE - Add 'E' prefix for hr-employee-id (aka ucpath_employee_id) identifier
#  DONE - Format phone number

# encoding = "UTF-8"
# 10000050 - address "preferred" should be "true||false" DONE
#            address start_date : 2021-07-27  (not 2024-10-31)
#            address start_date : 2023-10-31  (not 2023-10-31)
#            email_type "school" not "BUSN" DONE
#            phone - should be 510-643-6532/office/preferred = true I had none... DONE
# 10144264 - user_group "LIBSTAFF" not NONACAD
#          - purge date '2023', not '2024'
#          

require 'getoptlong'
require 'zipruby'

# Load library
require_relative 'config/config'
require_relative 'lib/alma'
require_relative 'lib/ldap'
require_relative 'lib/sis'
require_relative 'lib/ucpath'

# Include modules
include Alma
include LDAP
include UCPath

$logger = Logger.new( 'log/log.txt', 'daily' )

# TODO - Set up options, build help menu!
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--type', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--startdate', '-s', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--enddate', '-e', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--numdays', '-n', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--users', '-u', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
  [ '--noupload', GetoptLong::NO_ARGUMENT ]
)

@num_days = Config.setting('change_log_days')

opts.each do |opt, arg|
  case opt
    when '--help'
      puts Config.help
      exit
    when '--type'
      @type = arg
    when '--startdate'
      @start_date = arg
    when '--enddate'
      @end_date = arg
    when '--numdays'
      @num_days = arg.to_i
    when '--users'
      @users = arg.split(/\s*,\s*/)
    when '--noupload'
      @do_not_upload = true
    when '--verbose'
      $verbose = true
  end
end

# Filename:
# type_adhoc||daterange.xmlfilename_type = @type
filename_range = ''

$logger.info "Type: #{@type}"


if @users
  filename_range = 'adhoc'
  $logger.info "Running for specific users"
  $logger.info "User List: #{@users}"
  
  process_list = @users
else

  if @start_date || @end_date
    @num_days = @num_days - 1

    # If either start or end date are blank, then use num_days
    # to define the blank date.
    if @start_date.blank?
      @start_date = Date.iso8601(@end_date).next_day(-@num_days).to_s
    elsif @end_date.blank?
      @end_date = Date.iso8601(@start_date).next_day(+@num_days).to_s
    end

  else
    # By default we want to run an end date of yesterday:
    @end_date = Date.today - 1

    # Starting num_days (default 14) before yesterday
    @start_date = @end_date - (@num_days)

  end

  puts "---------- RUNNING CHANGE LOG ------------"
  puts "@start_date   : #{@start_date}"
  puts "@end_date     : #{@end_date}"
  puts "@num_days     : #{@num_days}"
  puts "--------------------------------------"
  filename_range = "#{@start_date}_#{@end_date}"

end


if @type == 'ucpath'
  user_list = []

  # Fetch the change log if we didn't specify users at the command line!
  process_list = UCPath::User.fetch_change_log(@start_date, @end_date) unless process_list

  # Stash the Change Log while developing...
  File.open("tmp/sfcl_#{filename_range}.txt", 'w') do |file|
    process_list.each do |id|
      file.write("#{id}\n")
    end
  end

  # $logger.info process_list
  
  # LET'S DO THIS!!!!
  $logger.info "About to process #{process_list.count} records..."
  if process_list
    process_list.each do |id|
      puts "\tFetching ID: #{id}" if $verbose
      u = UCPath::User.new(id)

      if u.is_eligible?
        user_list.push(u)
      else
        # LOG THE FAILURE - who...why
        puts "WARN : User ineligible..." if $verbose
      end
    end

    # BUILD XML
    builder = Alma::XMLBuilder.new user_list

    if $verbose
      puts "\n--------------------\n"
      puts "#{builder.doc.to_xml}"
      puts "\n--------------------\n"
    end

    # WRITE XML TO FILE
    f = File.open("#{@type}_#{filename_range}.xml", "w")
    f.write(builder.doc.to_xml)
    f.close

    $logger.info "Records writing to #{@type}_#{filename_range}.xml"
    
    # CREATE ZIP FILE AND ADD XML FILE TO IT
    # Zip::Archive.open('tmp/testzip.zip', Zip::CREATE) do |arc|
    #   arc.add_file('test_user_uploads.xml')
    #   $logger.info "File Zipped"
    # end
    
    
    # UPLOAD XML FILE???
    unless @do_not_upload
      # UPLOAD FILE TO....?
      # $logger.info "File Uploaded"
    end

  else
    # Log this? Error? Should we ALWAYS expect some recs?
    puts "\n\nWARNING - No Records Found\n\n"
    
  end

  

elsif @type == 'sis'
  # RUN SIS... well eventually, someday, when those SIS folks get off their butts and give access!
  puts "----->SIS"
  puts "one big todo list at this point!\n\n"
elsif @type == 'alma'
  # DEVELOPMENT ONLY....
  
  # Quick and dirty ALMA API Testing
  puts "----->ALMA"
  alma_user = Alma::API.fetch_alma_user('10335026')
  puts "---------- alma_user_load | line# 140 ------------"
  puts "user.inspect : #{alma_user.inspect}"
  puts "--------------------------------------"
elsif @type == 'ldap'
  # DEVELOPMENT ONLY....

  # Quick and dirty test of LDAP
  puts "\n\n----->TESTING LDAP"
  # LDAP::API.fetch_ldap_rec('1707532')
  puts "Student Affiliated? #{Config.student_affiated? 'STUDENT-TYPE-REGISTERED'}"
  puts "Student Affiliated? #{Config.student_affiated? 'STUDENT-TYPE-NOT REGISTERED'}"
else
  puts "\nERROR: type is required and must be 'sis' or 'ucpath'\n"
  exit
end



# STEPS:
#    COLLECT DATA:
#    01 - Generate list of users : change log or ad-hoc (specific IDs or daterange)
#    02 - Get UCPath Record
#    03 - Get LDAP Record
#    04 - Get ALMA Record
#    AGGREGATE:
#    05 - Create an Alma User Object
#    06 - If Alma rec exists check for differences and merge
#    MUNGE:
#    07 - Set roles, handle purges, etc...
#    08 - Generate XML Fragment (for individual user record)
#    09 - Add fragment to XML Doc (for collection)
#    EXPORT:
#    10 - Save XML file
#    11 - Zip file
#    12 - Send XML file to ??? (where Ex Libris collects files for sync/update)
#         FTP to: upload.lib.berkeley.edu/alma/
#                                              patron_employees
#                                              patron_students
#