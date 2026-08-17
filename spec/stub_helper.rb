# frozen_string_literal: false

require 'json'
require 'webmock'

def fixture_path(*parts)
  File.join('spec', 'data', *parts)
end

def fixture_body(*parts)
  File.read(fixture_path(*parts))
end

def fixture_json(*parts)
  JSON.parse(fixture_body(*parts))
end

def ucpath_user_url(id)
  "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}?id-type=hr-employee-id"
end

def ucpath_jobs_url(id)
  "https://gateway.api.berkeley.edu/hr/v3/employees/#{id}/jobs?id-type=hr-employee-id"
end

def ucpath_change_log_url(start_date, end_date)
  "https://gateway.api.berkeley.edu/hr/v3/employees?change-from=#{start_date}&change-to=#{end_date}&page-number=1&page-size=200"
end

def sis_data_url(term_id, page_num)
  "https://gateway.api.berkeley.edu/sis/v2/students?affiliation-status=ALL&inc-acad=true&inc-cntc=true&inc-regs=true&page-number=#{page_num}&page-size=50&term-id=#{term_id}"
end

def sis_past_data_url(term_id, as_of_date, page_num)
  "https://gateway.api.berkeley.edu/sis/v2/students?as-of-date=#{as_of_date}&affiliation-status=ALL&inc-acad=true&inc-cntc=true&inc-regs=true&page-number=#{page_num}&page-size=50&term-id=#{term_id}"
end

def stub_get(url, status: 200, body: nil)
  stub_request(:get, url).to_return(
    status: status,
    body: body
  )
end

def stub_ucpath_user(id)
  stub_get(ucpath_user_url(id), status: 200, body: fixture_body('ucpath', "#{id}_user.json"))
end

# Stubs the UCPath jobs endpoint.
# By default it uses the per-user jobs fixture, but a different fixture
# and field overrides can be supplied for scenario-based tests.
def stub_ucpath_jobs(id, fixture: nil, overrides: nil)
  fixture ||= "#{id}_jobs.json"

  if overrides
    json_body = fixture_json('ucpath', fixture)
    apply_job_overrides!(json_body, overrides)
    body = json_body.to_json
  else
    body = fixture_body('ucpath', fixture)
  end

  stub_get(ucpath_jobs_url(id), status: 200, body: body)
end

def apply_job_overrides!(json_body, overrides)
  job = json_body['response'][0]['jobs'][0]

  overrides.each do |key, value|
    case key
    when :job_code
      job['position']['jobCode']['code']['code'] = value
    when :dept_code
      job['department']['code'] = value
    when :classification_indc
      job['classification']['code'] = value
    when :termination_date
      job['actions']['terminationDate'] = value
    else
      raise ArgumentError, "Unknown job override key: #{key}"
    end
  end
end

def stub_ucpath_missing_user(id)
  stub_get(ucpath_user_url(id), status: 400)
end

def stub_ucpath_jobs_rate(id)
  stub_get(ucpath_jobs_url(id), status: 429)
end

def stub_change_log(start_date, end_date, fixture_name)
  stub_get(ucpath_change_log_url(start_date, end_date), status: 200, body: fixture_body('ucpath', "#{fixture_name}.json"))
end

def stub_empty_change_log(start_date, end_date)
  stub_get(ucpath_change_log_url(start_date, end_date), status: 200, body: nil)
end

def stub_past_sis_data(term_id, as_of_date, page_num)
  stub_get(sis_past_data_url(term_id, as_of_date, page_num), status: 200, body: fixture_body('sis', "past_#{term_id}_#{page_num}.json"))
end

def stub_sis_data(term_id, page_num, fixture: nil)
  fixture ||= "term_#{term_id}_#{page_num}.json"

  stub_get(
    sis_data_url(term_id, page_num),
    status: 200,
    body: fixture_body('sis', fixture)
  )
end

def stub_missing_sis_data(term_id, page_num)
  stub_get(sis_data_url(term_id, page_num), status: 200, body: fixture_body('sis', "missing_reg_#{term_id}_#{page_num}.json"))
end
