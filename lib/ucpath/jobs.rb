require 'date'
require 'json'
require 'ostruct'
require 'jsonpath'
require 'nokogiri'
require_relative '../alma'

module UCPath
  class Jobs
    attr_accessor :job, :first_job

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
    def find_eligible_job(job_list)
      # Return priority job (see ucpath_codes.yml for list) if we have one
      priority_job_hash = find_priority_jobs(job_list)
      return map_job_to_struct(priority_job_hash) if priority_job_hash

      # No priority job so find the "best" eligible job!
      select_best_eligible_job(job_list.first)
    end

    def select_best_eligible_job(job_hashes)
      # Admission: I was using a long drawn out loop to go over the jobs
      # ChatGPT suggested I try using reduce to, well, reduce the number of lines!
      job_hashes.reduce(nil) do |best, job_hash|
        job = map_job_to_struct(job_hash)

        # Store the first job in case we can't find any eligible jobs
        # This can then be used to set a new expiry date.
        @first_job ||= job

        next best unless eligible?(job)

        best ? choose_job(best, job) : job
      end
    end

    def choose_job(job1, job2)
      # If either job has no expected end date....use it!
      return job1 if job1.expected_end_date.to_s.empty?
      return job2 if job2.expected_end_date.to_s.empty?

      # If both jobs have an expected end date, return the one
      # that is furthest into the future
      date1 = Date.parse(job1.expected_end_date)
      date2 = Date.parse(job2.expected_end_date)

      date1 > date2 ? job1 : job2
    end

    def eligible?(j)
      # There are 3 conditions that determine if a job is "not eligible":
      # 1. hrStatus/code = A
      return false unless j.hr_status_code == 'A'

      # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
      end_date_str = j.expected_end_date.to_s
      return false if end_date_str != '' && Date.iso8601(end_date_str) <= Date.today

      # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within
      #    the Visiting Scholar category
      #    or UCB Academic Dept Affiliate Code (per SD-97)
      if j.org_relationship_code == 'CWR'
        visiting_scholar = Config.check_ucpath_code('visiting_scholar_job_code', j.job_code)
        academic_affiliate = Config.check_ucpath_code('ucb_academic_dept_affiliate_code', j.job_code)

        return false unless visiting_scholar || academic_affiliate
      end

      # If we got this far the job is eligible - hooray!
      true
    end

    def find_priority_jobs(job_list)
      job_list.flatten.find do |jh|
        job_code = jh.dig('position', 'jobCode', 'code', 'code')
        status = jh.dig('status', 'hrStatus', 'code')

        Config.check_ucpath_code('priority_job_codes', job_code) && status == 'A'
      end
    end

    def map_job_to_struct(job_hash)
      OpenStruct.new(
        Config.ucpath_job_fields.to_h do |field|
          [field['name'], JsonPath.on(job_hash, field['jpath']).first || '']
        end
      )
    end

    def fetch_jobs(id)
      logger.info "#{id} - Fetching ucpath jobs data"
      User.fetch_ucpath_jobs(id)
    end

  end
end
