# frozen_string_literal: true

require 'date'
require 'zipruby'
require 'getoptlong'
require 'digest/md5'

# Load library
require_relative 'config/config'
require_relative 'lib/alma'
require_relative 'lib/ldap'
require_relative 'lib/sis'
require_relative 'lib/ucpath'
require_relative 'lib/logging'

# Include modules
# rubocop:disable Style/MixinUsage
include SIS
include Alma
include LDAP
include UCPath
include Logging
# rubocop:enable Style/MixinUsage

# TODO: - Set up options, build help menu!
opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--type', '-t', GetoptLong::REQUIRED_ARGUMENT],
  ['--startdate', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--enddate', '-e', GetoptLong::REQUIRED_ARGUMENT],
  ['--numdays', '-n', GetoptLong::REQUIRED_ARGUMENT],
  ['--users', '-u', GetoptLong::REQUIRED_ARGUMENT],
  ['--term', GetoptLong::REQUIRED_ARGUMENT],
  ['--noupload', GetoptLong::NO_ARGUMENT]
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
  when '--term'
    @term_id = arg
  when '--noupload'
    @do_not_upload = true
  end
end

# Filename:
# type_adhoc||daterange.xmlfilename_type = @type
filename_range = ''

logger.info "Type: #{@type}"

if @users
  filename_range = 'adhoc'
  logger.info 'Running for specific users'
  logger.info "User List: #{@users}"

  process_list = @users
else

  if @start_date || @end_date
    @num_days -= 1

    # If either start or end date are blank, then use num_days
    # to define the blank date.
    if !@start_date || @start_date == ''
      @start_date = Date.iso8601(@end_date).next_day(-@num_days).to_s
    elsif !@end_date || @end_date == ''
      @end_date = Date.iso8601(@start_date).next_day(+@num_days).to_s
    end

  else
    # By default we want to run an end date of yesterday:
    @end_date = Date.today - 1

    # Starting num_days (default 14) before yesterday
    @start_date = @end_date - @num_days

  end

  filename_range = "#{@start_date}_#{@end_date}"
end

# TODO: This should really be extracted to a separate module
case @type
when 'ucpath'
  user_list = []

  logger.info "Start Date : #{@start_date}"
  logger.info "End Date   : #{@end_date}"

  # Fetch the change log if we didn't specify users at the command line!
  # process_list = UCPath::User.fetch_change_log(@start_date, @end_date) unless process_list
  process_list ||= UCPath::API.change_log(@start_date, @end_date)

  # TODO: move this someplace....
  # Stash the Change Log while developing...
  File.open("tmp/sfcl_#{filename_range}.txt", 'w') do |file|
    process_list.each do |id|
      file.write("#{id}\n")
    end
  end

  logger.info process_list

  # LET'S DO THIS!!!!
  logger.info "About to process #{process_list.count} records..."

  if process_list

    # Fetch and Process each ID from process_list
    process_list.each do |id|
      u = UCPath::User.new(id)

      user_list.push(u) if u.eligible?
    end

    # BUILD XML
    builder = Alma::XMLBuilder.new user_list

    # WRITE XML TO FILE
    f = File.open("#{@type}_#{filename_range}.xml", 'w')
    f.write(builder.doc.to_xml)
    f.close

    logger.info "Records writing to #{@type}_#{filename_range}.xml"

    # CREATE ZIP FILE AND ADD XML FILE TO IT
    # Zip::Archive.open('tmp/testzip.zip', Zip::CREATE) do |arc|
    #   arc.add_file('test_user_uploads.xml')
    #   logger.info "File Zipped"
    # end

    # UPLOAD XML FILE???
    unless @do_not_upload
      # UPLOAD FILE TO....?
      # logger.info 'File Uploaded'
    end

  else
    # Log this? Error? Should we ALWAYS expect some recs?
    puts "\n\nWARNING - No Records Found\n\n"
  end

when 'sis'

  # We'll populate our list of eligible users into this array
  user_list = []

  # BY TERM:
  @term_id ||= SIS::API.current_term

  # Because SIS does NOT have a change log, I need to do this in two
  # passes. First query using an 'as-of-date' set to a week ago, this
  # will give me a "snapshot" of their data at that time.
  # Convert each user record into a checksum and load it into
  # a hash (past_data_hash) with the ID as the key and MD5 the value.
  # Then query the current data (same API call but without the as-of-date)
  # and go through each user and check the past_data_hash to see if the
  # ID exists there - if it does, and the checksums don't equate, then
  # that record has been updated - add it to the user list, if the ID
  # does not exist, it's a new record, add it to the user list.
  # The user list is then sent to the Alma XML builder and wa-la!
  # out comes a delicious XML document... it's just that easy!

  today = Date.today
  lookback_date = (today - Config.setting('sis_look_back')).to_s

  logger.info 'Processing SIS'
  logger.info "Term: #{@term_id}"
  logger.info "Going Back to: #{lookback_date}"

  #----------------------------------------------------------------#
  # First fetch the term for the as-of-date == lookback_date

  # This will hold the snap shot of what the data looked like a week ago
  past_data_hash = {}

  past_data = SIS::API.fetch_by_term(@term_id, lookback_date)

  past_data.each_with_index do |user, _idx|
    student = SIS::Student.new(user)
    id = student.rec.primary_id
    md5 = Digest::MD5.hexdigest(student.rec.to_s)
    past_data_hash[id] = md5
  end

  #----------------------------------------------------------------#
  # Now fetch the term for the as-of-date == current date
  counter = 0
  raw_users = SIS::API.fetch_by_term(@term_id)
  raw_users.each_with_index do |user, _idx|
    student = SIS::Student.new(user)
    id = student.rec.primary_id
    md5 = Digest::MD5.hexdigest(student.rec.to_s)

    if past_data_hash.key?(id)
      # If the checksums don't match - add the record to the user list
      if past_data_hash[id] != md5
        logger.info "#{id} - #{md5}"
        counter += 1
        user_list.push(student)
      end
    else
      # New Record, add it to the user list
      counter += 1
      logger.info "#{id} - #{md5}"
      user_list.push(student)
    end
  end

  logger.info "Total new and changed records: #{counter}"
  puts "Total new and changed records: #{counter}"

  # BUILD XML
  builder = Alma::XMLBuilder.new user_list

  # WRITE XML TO FILE
  filename_prefix = "#{@type}_#{lookback_date}-#{today}"

  logger.info "Writing XML File: #{filename_prefix}.xml"
  f = File.open("#{filename_prefix}.xml", 'w')
  f.write(builder.doc.to_xml)
  f.close

  # CREATE ZIP FILE AND ADD XML FILE TO IT
  Zip::Archive.open("#{filename_prefix}.zip", Zip::CREATE) do |arc|
    arc.add_file("#{filename_prefix}.xml")
    logger.info "File Zipped: #{filename_prefix}.zip"
  end

  # TODO: setup FTP
  # sftp [username]@upload.lib.berkeley.edu
  # alma/
  #   patron_employees/
  #   patron_students/
  #   sandbox/
  #     patron_employees/
when 'sftp'
  puts "SFTP'ing file..."
else
  puts "\nERROR: type is required and must be 'sis' or 'ucpath'\n"
  exit
end

__END__
TODO: -
 DONE - See if I can do an SIS change log using as-of-date (YES - and done!)
 DONE - SIS - Set Expiry and Purge Dates
 DONE - SIS - add inc-regs and grab the withcncl code value!!!
 DONE - SIS - Add Unit Testing
 DONE - Get code coverage to 100%
 DONE - Setup logging (guess do a csv file per run... )
 DONE - Fix address start date
 DONE - Setup RSPEC
 DONE - Setup RCOV
 DONE - Workout the address start/end dates - it's unclear what they should be (Becky is working on this)
 DONE - Make file naming convention dynamic? (add date, type, etc...)
 DONE - Move Keys/PWs to config and ENV vars
 DONE - Setup LDAP fields
 DONE - Setup user aggregation/merge
 DONE - Get this into Gitlab!!!
 DONE - Setup "Eligibility" logic!!!
 DONE - Setup better XML builder/template writer
 DONE - switch to use JSON for all data collection (UCPath/SIS/Alma)
 DONE - Setup to zip the xml file
 DONE - Add 'E' prefix for hr-employee-id (aka ucpath_employee_id) identifier
 DONE - Format phone number
 DONE - SIS - keep only last 8 chars for primary id in barcode field!
 DONE - update <campus_code>UCB Campus</campus_code> to <campus_code>UCB_Campus</campus_code>
 DONE - replace user group UCBX with UCEXTSTUD
 
 SEGREGATE THE UCPATH AND SIS PROCESSES Above TO MODULES
 Verify I have all "required" fields for eligibility
 TODO - replace fixtures w/some sort of factory (factorybot?)
 STARTED - Setup SIS process
 STARTED - Setup options
 STARTED - REFACTOR the living shit out this
 STARTED - Clean up your config setup - it's a bit unruly right now
 SIS - Check on Identifiers logic (student-id particularly)
 SIS - Improve logging!!!
 Setup error handling!!!!
 STARTED - Rubocop it!
 Write test to check that we make expected job date in past ineligible!
 Move to Gitlab/Lap
 Setup DockerFile
 Setup in pipeline
 Setup transfer of zip file to Ex Libris
 Setup full user base (if we want that...sounds scary)
 Write up README
 DRY things up (UCPath vs. SIS --> phone, email, address, names, etc...)
 Save the change log to a temp file and go through (and track your progress)
 Only do a LDAP lookup if you have an eligible job!!!
 Go through the million "TODOs" littered through all this code!
 Eventually build out custom logger (CSV of each record touched, each event and outcome)
 Add some resiliency - maybe log progress so if there's an interuption I can restart from the last place
 no phone number - don't add phone group at all! HRmmmm... 