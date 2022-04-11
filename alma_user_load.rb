# !/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'zip'
require 'date'
require 'getoptlong'
require 'net/sftp'
require 'digest/md5'

# Load library
require_relative 'config/config'
require_relative 'lib/docker'
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

opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--type', '-t', GetoptLong::REQUIRED_ARGUMENT],
  ['--startdate', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--enddate', '-e', GetoptLong::REQUIRED_ARGUMENT],
  ['--numdays', '-n', GetoptLong::REQUIRED_ARGUMENT],
  ['--users', '-u', GetoptLong::REQUIRED_ARGUMENT],
  ['--term', GetoptLong::REQUIRED_ARGUMENT],
  ['--outdir', '-o', GetoptLong::REQUIRED_ARGUMENT]
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
  when '--outdir'
    @outdir = arg
  end
end

# Filename:
# type_adhoc||daterange.xmlfilename_type = @type
filename_range = ''

logger.info "Type: #{@type}"

# If we didn't pass an output directory use the current working directory
@outdir ||= Dir.pwd

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

case @type
when 'ucpath'
  logger.info "Start Date : #{@start_date}"
  logger.info "End Date   : #{@end_date}"

  # Fetch the change log if we didn't specify users at the command line!
  process_list ||= UCPath::API.change_log(@start_date, @end_date)

  logger.info process_list

  # LET'S DO THIS!!!!
  if process_list
    logger.info "About to process #{process_list.count} records..."

    filename_prefix = "#{@type}_#{filename_range}"
    filepath = "#{@outdir}/#{filename_prefix}.xml"

    # Open the writer...
    writer = Alma::XMLWriter.new(filepath)

    # Fetch and Process each ID from process_list
    process_list.each_with_index do |id, idx|
      logger.info "#{idx} - #{id}"

      u = UCPath::User.new(id)

      writer.write(u) if u.eligible?
    end

    # Close the writer!
    writer.close

    # Zip it!
    Zip::File.open("#{@outdir}/#{filename_prefix}.zip", create: true) do |arc|
      arc.add("#{filename_prefix}.xml", "#{@outdir}/#{filename_prefix}.xml")
      logger.info "File Zipped: #{@outdir}/#{filename_prefix}.zip"
    end

  else
    logger.info 'WARNING - No Records Found'
  end

when 'sis'
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
  # First fetch the term for the as-of-date (aka lookback_date)

  # This will hold the snap shot of what the data looked like a week ago
  past_data_hash = {}

  past_data = SIS::API.fetch_by_term(@term_id, lookback_date)

  past_data.each do |user|
    student = SIS::Student.new(user)
    id = student.rec.primary_id
    md5 = Digest::MD5.hexdigest(student.rec.to_s)
    past_data_hash[id] = md5
  end

  #----------------------------------------------------------------#
  # Setup your XML file and writer
  filename_prefix = "#{@type}_#{lookback_date}-#{today}"
  filepath = "#{@outdir}/#{filename_prefix}.xml"
  writer = Alma::XMLWriter.new(filepath)

  #----------------------------------------------------------------#
  # Now fetch the term for the as-of-date == current date
  raw_users = SIS::API.fetch_by_term(@term_id)
  raw_users.each do |user|
    student = SIS::Student.new(user)
    id = student.rec.primary_id
    md5 = Digest::MD5.hexdigest(student.rec.to_s)

    if past_data_hash.key?(id)
      # Checksums don't match the record has changed - write it
      writer.write(student) if past_data_hash[id] != md5
    else
      # New Record - write it!
      writer.write(student)
    end
  end

  writer.close

  # Zip it
  Zip::File.open("#{@outdir}/#{filename_prefix}.zip", create: true) do |arc|
    arc.add("#{filename_prefix}.xml", "#{@outdir}/#{filename_prefix}.xml")
    logger.info "File Zipped: #{@outdir}/#{filename_prefix}.zip"
  end

else
  puts "\nERROR: type is required and must be 'sis' or 'ucpath'\n"
  logger.error "Type is required and must be 'sis' or 'ucpath'"
  exit
end
