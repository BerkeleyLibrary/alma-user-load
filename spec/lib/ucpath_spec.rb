require 'spec_helper'
require 'stub_helper'
require 'ldap_helper'

# rubocop:disable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength
describe UCPath do
  it 'does not create a file if changelog returns zero records' do
    stub_empty_change_log('2022-04-10', '2022-04-13')

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '-s', '2022-04-10', '-e', '2022-04-13', '--outdir', outpath]
      setup = Helpers::Setup.new

      UCPath.run_ucpath setup

      expect(File.exist?(setup.zip_path)).to be(false)
      expect(File.exist?(setup.xml_path)).to be(false)
    end
  end

  it 'runs ucpath' do
    stub_change_log('2022-04-10', '2022-04-13', 'change_log_1')
    stub_ucpath_user('10000003')
    stub_ucpath_jobs('10000003')
    stub_ucpath_user('10000004')
    stub_ucpath_jobs('10000004')

    # Mock LDAP
    allow(LDAP::API).to receive(:fetch_ldap_rec).with('112823').and_return(nil)
    allow(LDAP::API).to receive(:fetch_ldap_rec).with('1628831').and_return(nil)

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '-s', '2022-04-10', '-e', '2022-04-13', '--outdir', outpath]
      setup = Helpers::Setup.new
      UCPath.run_ucpath setup

      # Since the fixture is static but the start date value is dynamic we
      # need to swap that out before we do the comparison
      expected_file = File.read('spec/data/ucpath/expected_xml_1.xml')
      expected_file.gsub!(%r{<start_date>2022-04-19</start_date>}, "<start_date>#{Date.today}</start_date>")

      expect(File.exist?(setup.zip_path)).to be(true)
    end
  end

  it 'runs ucpath for a specific user' do
    id = '10000005'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    # Mock LDAP
    allow(LDAP::API).to receive(:fetch_ldap_rec).with('112823').and_return(nil)

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '--users', '10000005', '--outdir', outpath]
      setup = Helpers::Setup.new
      UCPath.run_ucpath setup

      expect(File.exist?(setup.zip_path)).to be(true)
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength

describe UCPath::API do
  it 'creates a change log' do
    s = '2021-01-01'
    e = '2021-01-03'

    stub_change_log(s, e, 'change_log_1')
    log = change_log(s, e)
    expect(log).to include('10000003', '10000004')
  end

  it 'returns nil on faraday error' do
    stub_request(:get, 'https://gateway.api.berkeley.edu/hr/v3/employees/dummy_id?id-type=hr-employee-id')
      .to_raise('API Error')

    expect { fetch_ucpath_rec('dummy_id') }.to raise_error(StandardError)
  end

  it 'retries on a 429 status' do
    id = '10527060'
    stub_ucpath_user(id)
    stub_ucpath_jobs_rate(id)
    u = UCPath::User.new(id)
    expect(u.jobs).to be_nil
  end
end

# rubocop:disable Metrics/BlockLength
describe UCPath::User do
  before do
    allow(Config.secrets.ldap).to receive(:pass).and_return('MISSING')
  end

  it 'is a ucpath user object' do
    id = '10527060'
    ldap_id = '1628831'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(nil)

    u = UCPath::User.new(id)
    expect(u).to be_kind_of(User)
  end

  it 'weeds out student affiliated users' do
    ucpath_id = '10527060'
    ldap_id = '1628831'

    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'berkeleyeduaffiliations' => ['STUDENT-TYPE-REGISTERED'] }
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.eligible?).to be(false)
  end

  it 'weeds out users without an email address' do
    ucpath_id = '123454321'
    ldap_id = '1628831'

    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] },
                        { 'berkeleyedualternateid' => [''] } # No email address
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.eligible?).to be(false)
  end

  it 'uses names from ldap if missing names in ucpath record' do
    ucpath_id = '12345678'
    ldap_id = '1628831'

    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.first_name).to eq('test_first_name')
    expect(u.rec.last_name).to eq('test_last_name')
  end

  describe 'user group assignment' do
    let(:ucpath_id) { '10527060' }
    let(:ldap_id) { '1628831' }

    before do
      stub_ucpath_user(ucpath_id)
      allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(nil)
    end

    [
      {
        description: 'LIBSTAFF',
        overrides: { job_code: '000118' },
        expected_group: 'LIBSTAFF'
      },
      {
        description: 'UCBVISSCHOL',
        overrides: { job_code: 'CWR003' },
        expected_group: 'UCBVISSCHOL'
      },
      {
        description: 'UCBAFFILI',
        overrides: { job_code: 'CWR022' },
        expected_group: 'UCBAFFILI'
      },
      {
        description: 'UCEXT',
        overrides: {
          job_code: 'dummycode',
          dept_code: 'EXADM',
          classification_indc: 'A'
        },
        expected_group: 'UCEXT'
      },
      {
        description: 'FACULTY',
        overrides: { job_code: '001132' },
        expected_group: 'FACULTY'
      },
      {
        description: 'EXECUTIVE',
        overrides: {
          job_code: 'dummycode',
          dept_code: 'dummycode',
          classification_indc: '2'
        },
        expected_group: 'EXECUTIVE'
      },
      {
        description: 'NONACAD',
        overrides: {
          job_code: 'dummycode',
          dept_code: 'dummycode',
          classification_indc: 'dummycode'
        },
        expected_group: 'NONACAD'
      }
    ].each do |row|
      it "sets user group #{row[:description]}" do
        stub_ucpath_jobs(
          ucpath_id,
          fixture: 'generic_jobs_2.json',
          overrides: row[:overrides]
        )

        u = UCPath::User.new(ucpath_id)

        expect(u.rec.user_group).to eq(row[:expected_group])
      end
    end
  end

  it 'uses the ldap phone number' do
    ucpath_id = '12345678'
    ldap_id = '1628831'

    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] },
                        { 'telephonenumber' => ['925-555-1234'] },
                        { 'berkeleyedualternateid' => ['fake@email.edu'] }
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.phone_number).to eq('925-555-1234')
  end

  it 'handles all known mangled telephone formats' do
    ucpath_id = '12345678'
    ldap_id = '1628831'

    known_phone_formats = [
      '510 645-1234',
      '5106451234',
      '645-1234',
      '5-1234'
    ]

    known_phone_formats.each do |number|
      stub_ucpath_user(ucpath_id)
      stub_ucpath_jobs(ucpath_id)

      stub_ldap_entries(ldap_id, [
                          { 'sn' => ['test_last_name'] },
                          { 'givenname' => ['test_first_name'] },
                          { 'telephonenumber' => [number] }
                        ])

      u = UCPath::User.new(ucpath_id)
      expect(u.rec.contact_info.phones.phone_number).to eq('510-645-1234')
    end
  end

  it 'handles non-primary phone number preferred attribute' do
    ucpath_id = '10000004'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.preferred).to eq('false')
  end

  it 'handles primary phone number preferred attribute' do
    ucpath_id = '10000005'
    ldap_id = '112823'

    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.preferred).to eq('true')
  end

  it 'creates expected expiry date if month is < change date (7)' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    current_year = Date.today.year
    expiration_year = current_year + 1
    fake_month = 6
    allow(Date).to receive(:today).and_return Date.new(current_year, fake_month, 1)

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.expiry_date).to eq("#{expiration_year}-10-31")
  end

  it 'creates expected expiry date if month is >= change date (7)' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    current_year = Date.today.year
    expiration_year = current_year + 2
    fake_month = 8
    allow(Date).to receive(:today).and_return Date.new(current_year, fake_month, 1)

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.expiry_date).to eq("#{expiration_year}-10-31")
  end

  it 'logs an error if the ucpath record is missing a required field' do
    id = '10000006'
    ldap_id = '1628831'

    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    u = UCPath::User.new(id)
    expect(u.errors).to include("#{id} - Missing required field: ucpath_employee_id")
  end

  it 'records an error if the ucpath record is not returned' do
    id = '10000666'
    stub_ucpath_missing_user(id)
    u = UCPath::User.new(id)
    expect(u.errors).to include('Failed to fetch UCPath record')
  end

  it 'LDAP::API returns nil if fetch encounters an error' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)
    allow(Net::LDAP).to receive(:new).and_raise(StandardError.new('error'))
    u = UCPath::User.new(ucpath_id)
    expect(u.ldap).to be_nil
  end

  it 'returns the first job if no eligible jobs are found' do
    id = '10145074'
    ldap_id = '7165'

    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    stub_ldap_entries(ldap_id, [
                        { 'sn' => ['test_last_name'] },
                        { 'givenname' => ['test_first_name'] }
                      ])

    u = UCPath::User.new(id)
    expect(u.rec.job_description).to eq('FIRST_JOB_DESCRIPTION')
  end

  it 'skips a user if no jobs are found' do
    id = '999999999'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    u = UCPath::User.new(id)

    expect(u.eligible?).to be(false)
  end

  it 'skips users that have a termination date before the last Alma purge date' do
    id = '888888888'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    u = UCPath::User.new(id)

    expect(u.eligible?).to be(false)
  end

  it 'skips users with a contingent worker job code' do
    id = '10000008'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    # Mock LDAP
    ldap_id = '112823'
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(nil)

    u = UCPath::User.new(id)
    expect(u.eligible?).to be(false)
  end

  it 'eligibility should be true for priority jobs even if the user has a student affiliation' do
    id = '10601882'
    ldap_id = '1772216'

    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    stub_ldap_entries(ldap_id, [
                        { 'berkeleyeduaffiliations' => ['STUDENT-TYPE-REGISTERED'] }
                      ])

    u = UCPath::User.new(id)
    expect(u.eligible?).to be(true)
  end

  it 'skips with VOID in first and last name fields' do
    id = '10725309'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    u = UCPath::User.new(id)
    expect(u.eligible?).to be(false)
  end

  it 'skips with zero Percentage of FullTime' do
    id = '10725310'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    u = UCPath::User.new(id)
    expect(u.eligible?).to be(false)
  end
end

describe UCPath::Jobs do
  subject(:jobs) { described_class.allocate }

  # Small helper wrappers so specs read cleanly even though methods are private
  def choose_job(job1, job2)
    jobs.send(:choose_job, job1, job2)
  end

  def eligible(job)
    jobs.send(:eligible?, job)
  end

  # Minimal structs to stand in for your “job” objects
  let(:choose_job_struct) { Struct.new(:expected_end_date) }
  let(:eligible_job_struct) do
    Struct.new(:hr_status_code, :expected_end_date, :org_relationship_code, :job_code, :percent_of_fulltime, :percent_of_fulltime_job)
  end

  describe '#choose_job' do
    context 'when job1 has no expected end date' do
      let(:job1) { choose_job_struct.new('') }
      let(:job2) { choose_job_struct.new('2026-01-01') }

      it 'returns job1' do
        expect(choose_job(job1, job2)).to be(job1)
      end
    end

    context 'when job2 has no expected end date' do
      let(:job1) { choose_job_struct.new('2026-01-01') }
      let(:job2) { choose_job_struct.new('') }

      it 'returns job2' do
        expect(choose_job(job1, job2)).to be(job2)
      end
    end

    context 'when both have expected end dates' do
      let(:job1) { choose_job_struct.new('2026-01-01') }
      let(:job2) { choose_job_struct.new('2026-06-01') }

      it 'returns the job with the later date' do
        expect(choose_job(job1, job2)).to be(job2)
      end
    end

    context 'when dates are equal' do
      let(:job1) { choose_job_struct.new('2026-01-01') }
      let(:job2) { choose_job_struct.new('2026-01-01') }

      it 'returns job2 (tie goes to second arg)' do
        expect(choose_job(job1, job2)).to be(job2)
      end
    end
  end

  describe '#eligible?' do
    let(:today) { Date.new(2026, 2, 23) }

    before do
      allow(Date).to receive(:today).and_return(today)
    end

    context "when hr_status_code is not 'A'" do
      let(:job) { eligible_job_struct.new('I', '', '', 'ANY', 1.0, 0.0) }

      it 'returns false' do
        expect(eligible(job)).to be(false)
      end
    end

    context "when hr_status_code is 'A' and expected_end_date is blank" do
      let(:job) { eligible_job_struct.new('A', '', '', 'ANY', 1.0, 0.0) }

      it 'returns true' do
        expect(eligible(job)).to be(true)
      end
    end

    context "when hr_status_code is 'A' and expected_end_date is after today" do
      let(:job) { eligible_job_struct.new('A', '2026-03-01', '', 'ANY', 1.0, 0.0) }

      it 'returns true' do
        expect(eligible(job)).to be(true)
      end
    end

    context "when hr_status_code is 'A' and expected_end_date is today" do
      let(:job) { eligible_job_struct.new('A', '2026-02-23', '', 'ANY', 1.0, 0.0) }

      it 'returns false (<= today is not eligible per implementation)' do
        expect(eligible(job)).to be(false)
      end
    end

    context "when hr_status_code is 'A' and expected_end_date is before today" do
      let(:job) { eligible_job_struct.new('A', '2026-02-01', '', 'ANY', 1.0, 0.0) }

      it 'returns false' do
        expect(eligible(job)).to be(false)
      end
    end

    context 'when org_relationship_code is blank and other conditions pass' do
      let(:job) { eligible_job_struct.new('A', '', '', 'ANY', 1.0, 0.0) }

      it 'returns true' do
        expect(eligible(job)).to be(true)
      end
    end

    context "when org_relationship_code is 'CWR' and job_code is NOT in either allowlist" do
      let(:job) { eligible_job_struct.new('A', '', 'CWR', 'NOT_ALLOWED', 1.0, 0.0) }

      before do
        allow(Config).to receive(:check_ucpath_code)
          .with('visiting_scholar_job_code', 'NOT_ALLOWED')
          .and_return(false)

        allow(Config).to receive(:check_ucpath_code)
          .with('ucb_academic_dept_affiliate_code', 'NOT_ALLOWED')
          .and_return(false)
      end

      it 'returns false' do
        expect(eligible(job)).to be(false)
      end
    end

    context "when org_relationship_code is 'CWR' and job_code IS in visiting_scholar_job_code" do
      let(:job) { eligible_job_struct.new('A', '', 'CWR', 'ALLOWED', 1.0, 0.0) }

      before do
        allow(Config).to receive(:check_ucpath_code)
          .with('visiting_scholar_job_code', 'ALLOWED')
          .and_return(true)

        allow(Config).to receive(:check_ucpath_code)
          .with('ucb_academic_dept_affiliate_code', 'ALLOWED')
          .and_return(false)
      end

      it 'returns true' do
        expect(eligible(job)).to be(true)
      end
    end

    context "when org_relationship_code is 'CWR' and job_code IS in ucb_academic_dept_affiliate_code" do
      let(:job) { eligible_job_struct.new('A', '', 'CWR', 'ALLOWED', 1.0, 0.0) }

      before do
        allow(Config).to receive(:check_ucpath_code)
          .with('visiting_scholar_job_code', 'ALLOWED')
          .and_return(false)

        allow(Config).to receive(:check_ucpath_code)
          .with('ucb_academic_dept_affiliate_code', 'ALLOWED')
          .and_return(true)
      end

      it 'returns true' do
        expect(eligible(job)).to be(true)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
