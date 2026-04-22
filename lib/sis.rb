require 'set'
require_relative 'sis/api'
require_relative 'sis/student'

# We now run SIS for the full user collection
# Previously we were attempting to mimic a "change log"
# for details check Jira ticket SD-51:
# https://ucblib.atlassian.net/browse/SD-51

module SIS
  include SIS::API

  def run_sis(setup)
    # Load the Ignore list: see AP-636 for details
    ignore_list = load_ignored_sis_ids

    term_id = setup.term_id || SIS::API.current_term
    as_of_date = SIS::API.as_of_date
    writer = Alma::XMLWriter.new(setup.xml_path)

    log_run(term_id, as_of_date)
    process_users(term_id, as_of_date, ignore_list, writer)
    finalize_output(writer, setup)
  end

  def log_run(term_id, as_of_date)
    logger.info "Running SIS\nTerm ID: #{term_id}\nRequest Root: #{sis_root} As-of-Date #{as_of_date}"
  end

  def process_users(term_id, as_of_date, ignore_list, writer)
    raw_users = SIS::API.fetch_by_term(term_id, as_of_date)

    raw_users.each do |user|
      next if ignored_user?(user, ignore_list)

      writer.write(SIS::Student.new(user))
    end
  end

  def finalize_output(writer, setup)
    writer.close
    Helpers::FileZip.zipit!(setup.zip_path, setup.xml_path)
  end

  def load_ignored_sis_ids(path = 'config/sis_ignore_ids.txt')
    return Set.new unless File.exist?(path)

    File.readlines(path, chomp: true)
      .map(&:strip)
      .reject { |line| line.empty? || line.start_with?('#') }
      .to_set
  end

  def ignored_user?(user, ignore_list)
    student_id = user['student_id']

    return false unless ignore_list.include?(student_id)

    logger.info "Skipping User #{student_id}: listed in SIS ignore file"
    true
  end
end
