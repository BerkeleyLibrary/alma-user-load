require 'digest/md5'

require_relative 'sis/api'
require_relative 'sis/student'

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

# I might want to create a separate SIS::Changelog sort of class
# load the start date checksums into that.
# Then, I can check eligibility by sending the current checksum to it
# which will check if the user should be added or not.
# Might make it easier to move some of this logic into the API
# then I can process records as I go rather than storing the entire student
# collection!

module SIS
  include SIS::API

  # If we want to switch to run ALL students without trying to use a changelog
  def run_sis(setup)
    puts "Running FULL SIS!!!"
    logger.info 'Running SIS'

    term_id = setup.term_id || SIS::API.current_term

    #----------------------------------------------------------------#
    # Setup our XML file
    writer = Alma::XMLWriter.new(setup.xml_path)

    #----------------------------------------------------------------#
    # Fetch the term the as-of-date == current date
    raw_users = SIS::API.fetch_by_term(term_id)
    raw_users.each do |user|
      writer.write(SIS::Student.new(user))
    end

    writer.close

    Helpers::FileZip.zipit!(setup.zip_path, setup.xml_path)
  end

  # rubocop :disable Metrics/AbcSize, Metrics/MethodLength
  def run_sis_old(setup)
    logger.info 'Running SIS'

    term_id = setup.term_id || SIS::API.current_term

    logger.info "Start Date: #{setup.start_date}"

    # We'll store the checksums for the past data here
    past_data_hash = {}

    #----------------------------------------------------------------#
    # Fetch term with as of date == start date (default: a week ago)
    past_data = SIS::API.fetch_by_term(term_id, setup.start_date)
    past_data.each do |user|
      student = SIS::Student.new(user)
      id = student.rec.primary_id
      md5 = Digest::MD5.hexdigest(student.rec.to_s)
      past_data_hash[id] = md5
    end

    #----------------------------------------------------------------#
    # Recover some memory
    # rubocop :disable Lint/UselessAssignment
    past_data = nil
    # rubocop :enable Lint/UselessAssignment

    #----------------------------------------------------------------#
    # Setup our XML file
    writer = Alma::XMLWriter.new(setup.xml_path)

    #----------------------------------------------------------------#
    # Fetch the term with the as-of-date == current date
    raw_users = SIS::API.fetch_by_term(term_id)
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

    Helpers::FileZip.zipit!(setup.zip_path, setup.xml_path)
  end
  # rubocop :enable Metrics/AbcSize, Metrics/MethodLength
end
