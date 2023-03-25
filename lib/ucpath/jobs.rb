require 'date'
require 'json'
require 'ostruct'
require 'jsonpath'
require 'nokogiri'
require_relative '../alma'

module UCPath
  class Jobs
    attr_accessor :job

    def initialize(id)
      # Fetch the raw job data
      job_data = fetch_jobs(id)
      logger.info "#{id} - Fetching ucpath jobs data"
      return if job_data.nil?

      # Break the jobs data into an array using jsonpath
      raw_jobs = JsonPath.on(job_data, '$..response[*].jobs')
      return unless raw_jobs.count.positive?

      @job = find_eligible_job(raw_jobs)
    end

    def eligible_job?
      # If @job is NOT nil then we have an eligible job
      !@job.nil?
    end

    private

    # Extract the data from the raw jobs into the fields we need
    def find_eligible_job(raw_jobs)
      raw_jobs.first.each do |job_hash|
        j = job_hash.to_json

        job = OpenStruct.new

        # config/ucpath_fields.yml contains the fields/jpath we need
        Config.ucpath_job_fields.each do |field|
          value = JsonPath.on(j, field['jpath']).first || ''
          job[field['name']] = value if value
        end

        # Return this job struct if it's eligible
        return job if check_if_eligible(job)
      end

      # No eligible jobs found, return nil
      nil
    end

    # rubocop :disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def check_if_eligible(j)
      # Assume this job is eligible - this is based on the 3 criteria below
      job_eligible = true

      # 1. hrStatus/code = A
      job_eligible = false unless j.hr_status_code == 'A'

      # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
      job_eligible = false if !(!j.expected_end_date || j.expected_end_date == '') && (Date.iso8601(j.expected_end_date) <= Date.today)

      # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within
      #    the Visiting Scholar category
      #    or UCB Academic Dept Affiliate Code (per SD-97)
      if !(!j.org_relationship_code || j.org_relationship_code == '') && j.org_relationship_code == 'CWR' && (!Config.check_ucpath_code(
        'Visiting Scholar Job Code', j.job_code
      ) &&
            !Config.check_ucpath_code('UCB Academic Dept Affiliate Code', j.job_code))
        job_eligible = false
      end

      # return if the job is eligible or not
      job_eligible
    end
    # rubocop :enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def fetch_jobs(id)
      logger.info "#{id} - Fetching ucpath jobs data"
      User.fetch_ucpath_jobs(id)
    end

  end
end

__END__

def eligible_job?
  ineligible_reasons = []

  ucpath_rec.jobs.each do |j|
    # Assume this job is eligible - this is based on the 3 criteria below
    job_eligible = true

    # 1. hrStatus/code = A
    unless j.hr_status_code == 'A'
      ineligible_reasons.push("#{rec.primary_id} - Ineligible: HR status code: '#{j.hr_status_code}' - must be 'A'")
      job_eligible = false
    end

    # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
    # unless j.expected_end_date.blank?
    unless !j.expected_end_date || j.expected_end_date == ''
      ineligible_reasons.push("#{rec.primary_id} - Ineligible: expected_end_date not in the future")
      job_eligible = false if Date.iso8601(j.expected_end_date) <= Date.today
    end

    # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within
    #    the Visiting Scholar category.
    # unless j.org_relationship_code.blank?
    if !(!j.org_relationship_code || j.org_relationship_code == '') && (j.org_relationship_code == 'CWR')
      ineligible_reasons.push("#{rec.primary_id} - Ineligible: org code CWR has non visiting scholar job code")
      job_eligible = false unless Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
    end

    next unless job_eligible

    # Found eligible job - clear out any previous ineligible reasons
    ineligible_reasons = nil
    return true
  end

  ineligible_reasons&.each do |r|
    logger.info r
  end
  false
end