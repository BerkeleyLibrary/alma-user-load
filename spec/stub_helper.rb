# frozen_string_literal: false

require 'json'
require 'webmock'

# TODO: see if I can set this up to allow for overrides
#        e.g., stub_ucpath_user(id, {'name' => 'Rickey Bobby'})
def stub_ucpath_user(id)
  user_api_url = "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}?id-type=hr-employee-id"

  stub_request(:get, user_api_url).to_return(
    status: 200,
    body: File.new("spec/data/ucpath/#{id}_user.json")
  )
end

def stub_ucpath_missing_user(id)
  user_api_url = "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}?id-type=hr-employee-id"

  stub_request(:get, user_api_url).to_return(
    status: 400
  )
end

def stub_ucpath_jobs(id)
  user_api_url = "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}/jobs?id-type=hr-employee-id"

  stub_request(:get, user_api_url).to_return(
    status: 200,
    body: File.new("spec/data/ucpath/#{id}_jobs.json")
  )
end

def stub_ucpath_jobs_rate(id)
  user_api_url = "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}/jobs?id-type=hr-employee-id"

  stub_request(:get, user_api_url).to_return(
    status: 429
  )
end

# Recieves ID and "overrides" where we can set certain fields in the
# fixture at runtime so I don't have to create separate fixtures.
# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def override_jobs_stub(id, *overrides)
  user_api_url = "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}/jobs?id-type=hr-employee-id"

  body = File.read('spec/data/ucpath/generic_jobs_2.json')
  json_body = JSON.parse(body)

  if overrides && overrides[0]
    overrides[0].each_key do |key|
      case key
      when 'job_code'
        # jpath: '$.position.jobCode.code.code'
        json_body['response'][0]['jobs'][0]['position']['jobCode']['code']['code'] = overrides[0]['job_code']
      when 'dept_code'
        # jpath: '$.department.code'
        json_body['response'][0]['jobs'][0]['department']['code'] = overrides[0]['dept_code']
      when 'classification_indc'
        # jpath: '$.classification.code'
        json_body['response'][0]['jobs'][0]['classification']['code'] = overrides[0]['classification_indc']
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  new_body = json_body.to_json

  stub_request(:get, user_api_url).to_return(
    status: 200,
    body: new_body
  )
end

def stub_change_log(start_date, end_date, body)
  change_log_url = "https://gateway.api.berkeley.edu/hr/v3/employees?change-from=#{start_date}&change-to=#{end_date}&page-number=1&page-size=200"

  stub_request(:get, change_log_url).to_return(
    status: 200,
    body: File.new("spec/data/ucpath/#{body}.json")
  )
end

def stub_empty_change_log(start_date, end_date)
  change_log_url = "https://gateway.api.berkeley.edu/hr/v3/employees?change-from=#{start_date}&change-to=#{end_date}&page-number=1&page-size=200"

  stub_request(:get, change_log_url).to_return(
    status: 200,
    body: nil
  )
end

def stub_past_sis_data(term_id, as_of_date, page_num)
  sis_fetch_url = "https://gateway.api.berkeley.edu/sis/v2/students?as-of-date=#{as_of_date}&affiliation-status=ALL&inc-acad=true&inc-cntc=true&inc-regs=true&page-number=#{page_num}&page-size=50&term-id=#{term_id}"
  stub_request(:get, sis_fetch_url).to_return(
    status: 200,
    body: File.new("spec/data/sis/past_#{term_id}_#{page_num}.json")
  )
end

def stub_sis_data(term_id, page_num)
  sis_fetch_url = "https://gateway.api.berkeley.edu/sis/v2/students?affiliation-status=ALL&inc-acad=true&inc-cntc=true&inc-regs=true&page-number=#{page_num}&page-size=50&term-id=#{term_id}"
  stub_request(:get, sis_fetch_url).to_return(
    status: 200,
    body: File.new("spec/data/sis/term_#{term_id}_#{page_num}.json")
  )
end

def stub_missing_sis_data(term_id, page_num)
  sis_fetch_url = "https://gateway.api.berkeley.edu/sis/v2/students?affiliation-status=ALL&inc-acad=true&inc-cntc=true&inc-regs=true&page-number=#{page_num}&page-size=50&term-id=#{term_id}"
  stub_request(:get, sis_fetch_url).to_return(
    status: 200,
    body: File.new("spec/data/sis/missing_reg_#{term_id}_#{page_num}.json")
  )
end
