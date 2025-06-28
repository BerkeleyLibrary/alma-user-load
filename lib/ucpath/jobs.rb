require 'date'
require 'json'
require 'ostruct'
require 'jsonpath'
require 'nokogiri'
require_relative '../alma'

module UCPath
  class Jobs
    attr_accessor :job, :first_job

    class << self
      # We're no longer skipping users who do not have an eligible job.
      # But we still need a "job record" quick and dirty to create a dummy job
      # and set the expiration date (expected_end_date) to today.
      def dummy_job
        OpenStruct.new(
          hr_status_code: 'I',
          expected_end_date: Date.today.to_s,
          org_relationship_code: nil,
          dept_desc: '',
          job_code: nil
        )
      end
    end

    def initialize(id)
      # Fetch the raw job data
      job_data = fetch_jobs(id)
      logger.info "#{id} - Fetching ucpath jobs data"
      return if job_data.nil?

      # Break the jobs data into an array using jsonpath
      job_list = JsonPath.on(job_data, '$..response[*].jobs')
      return unless job_list.count.positive?

      @job = find_eligible_job(job_list)
    end

    def eligible_job?
      # If @job is NOT nil then we have an eligible job
      !@job.nil?
    end

    private

    # Extract the data from the raw jobs into the fields we need
    # config/ucpath_fields.yml contains the fields/jpath we want to extract
    def find_eligible_job(raw_jobs)
      raw_jobs.first.each do |job_hash|
        job = OpenStruct.new(
          Config.ucpath_job_fields.to_h do |field|
            [field['name'], JsonPath.on(job_hash, field['jpath']).first || '']
          end
        )

        # First one - save it incase we don't find any eligible jobs!
        @first_job ||= job
        return job if check_if_eligible(job)
      end

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
