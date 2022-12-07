require_relative 'sis/api'
require_relative 'sis/student'

# We now run SIS for the full user collection
# Previously we were attempting to mimic a "change log"
# for details check Jira ticket SD-51:
# https://ucblib.atlassian.net/browse/SD-51

module SIS
  include SIS::API

  def run_sis(setup)
    term_id = setup.term_id || SIS::API.current_term
    as_of_date = SIS::API.as_of_date

    logger.info "Running SIS\nTerm ID: #{term_id}\nRequest Root: #{sis_root} As-of-Date #{as_of_date}"

    #----------------------------------------------------------------#
    # Setup our XML file
    writer = Alma::XMLWriter.new(setup.xml_path)

    #----------------------------------------------------------------#
    # Fetch the entire set of users by term
    raw_users = SIS::API.fetch_by_term(term_id, as_of_date)
    raw_users.each do |user|
      writer.write(SIS::Student.new(user))
    end

    writer.close

    Helpers::FileZip.zipit!(setup.zip_path, setup.xml_path)
  end
end
