# frozen_string_literal: false

require 'spec_helper'
require 'stub_helper'
require 'ostruct'

# rubocop :disable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength
describe UCPath do
  it 'does not create a file if changelog returns zero records' do
    stub_empty_change_log('2022-04-10', '2022-04-13')

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '-s', '2022-04-10', '-e', '2022-04-13', '--outdir', outpath]
      setup = Helpers::Setup.new

      UCPath.run_ucpath setup

      expect(File.exist?(setup.zip_path)).to eq(false)
      expect(File.exist?(setup.xml_path)).to eq(false)
    end
  end

  it 'runs ucpath' do
    stub_change_log('2022-04-10', '2022-04-13', 'change_log_1')
    stub_ucpath_user('10000003')
    stub_ucpath_jobs('10000003')
    stub_ucpath_user('10000004')
    stub_ucpath_jobs('10000004')

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '-s', '2022-04-10', '-e', '2022-04-13', '--outdir', outpath]
      setup = Helpers::Setup.new
      UCPath.run_ucpath setup

      # Since the fixture is static but the start date value is dynamic we
      # need to swap that out before we do the comparison
      expected_file = File.read('spec/data/ucpath/expected_xml_1.xml')
      expected_file.gsub!(%r{<start_date>2022-04-19</start_date>}, "<start_date>#{Date.today}</start_date>")

      expect(File.exist?(setup.zip_path)).to eq(true)
      expect(File.read(setup.xml_path)).to eq(expected_file)
    end
  end

  it 'runs ucpath for a specific user' do
    id = '10000005'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'ucpath', '--users', '10000005', '--outdir', outpath]
      setup = Helpers::Setup.new
      UCPath.run_ucpath setup

      expect(File.exist?(setup.zip_path)).to eq(true)
    end
  end
end
# rubocop :enable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength

describe UCPath::API do
  it 'creates a change log' do
    s = '2021-01-01'
    e = '2021-01-03'

    stub_change_log(s, e, 'change_log_1')
    log = change_log(s, e)
    expect(log).to include('10000003', '10000004')
  end

  it 'returns nil on faraday error' do
    stub_request(:get, 'https://apis.berkeley.edu/hr/v3/employees/dummy_id?id-type=hr-employee-id')
      .to_raise('fake error')

    u = fetch_ucpath_rec('dummy_id')
    expect(u).to be_nil
  end
end

# rubocop:disable Metrics/BlockLength
describe UCPath::User do
  it 'is a ucpath user object' do
    id = '10527060'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)

    u = UCPath::User.new(id)
    expect(u).to be_kind_of(User)
  end

  it 'weeds out student affliated users' do
    ucpath_id = '10527060'
    ldap_id = '1628831'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'berkeleyeduaffiliations' => ['STUDENT-TYPE-REGISTERED'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0])

    u = UCPath::User.new(ucpath_id)
    expect(u.eligible?).to be(false)
  end

  it 'uses names from ldap if missing names in ucpath record' do
    ucpath_id = '12345678'
    ldap_id = '1628831'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.first_name).to eq('test_first_name')
    expect(u.rec.last_name).to eq('test_last_name')
  end

  it 'marks job ineligible if hr_status_code is not "A"' do
    ucpath_id = '10000003'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    u = UCPath::User.new(ucpath_id)
    expect(u.eligible?).to be(false)
  end

  # Collapse these into a single array driven test
  it 'sets user group libstaff' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id,
                       {
                         'job_code' => '000118'
                       })

    u = UCPath::User.new(ucpath_id)

    expect(u.rec.user_group).to eq('LIBSTAFF')
  end

  it 'sets user group UCBVISSCHOL' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id,
                       {
                         'job_code' => 'CWR003'
                       })

    u = UCPath::User.new(ucpath_id)

    expect(u.rec.user_group).to eq('UCBVISSCHOL')
  end

  it 'sets user group UCEXT' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id,
                       {
                         'job_code' => 'dummycode',
                         'dept_code' => 'EXADM',
                         'classification_indc' => 'A'
                       })

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('UCEXT')
  end

  it 'sets user group FACULTY' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id,
                       {
                         'job_code' => '001132'
                       })

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('FACULTY')
  end

  it 'sets user group EXECUTIVE' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id,
                       {
                         'job_code' => 'dummycode',
                         'dept_code' => 'dummycode',
                         'classification_indc' => '2'
                       })

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('EXECUTIVE')
  end

  it 'sets user group NONACAD' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    override_jobs_stub(ucpath_id, {
                         'job_code' => 'dummycode',
                         'dept_code' => 'dummycode',
                         'classification_indc' => 'dummycode'
                       })

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('NONACAD')
  end

  it 'uses the ldap phone number' do
    ucpath_id = '12345678'
    ldap_id = '1628831'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # TODO: try to move this LDAP stub to stub_helper
    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] },
      { 'telephonenumber' => ['925-555-1234'] },
      { 'berkeleyeduofficialemail' => ['fake@email.edu'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1]).and_yield(entries[2]).and_yield(entries[3])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.phone_number).to eq('925-555-1234')
  end

  it 'handles all known mangled telephone formats' do
    known_phone_formats = [
      '510 645-1234',
      '5106451234',
      '645-1234',
      '5-1234'
    ]

    known_phone_formats.each do |number|
      ucpath_id = '12345678'
      ldap_id = '1628831'
      stub_ucpath_user(ucpath_id)
      stub_ucpath_jobs(ucpath_id)

      # STUB LDAP:
      ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
      ldap_params = {
        auth: { method: :simple,
                password: 'MISSING',
                username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
        host: 'ldap.berkeley.edu',
        port: 389
      }

      ldap_base = {
        base: 'ou=people,dc=berkeley,dc=edu',
        filter: ldap_filter
      }

      entries = [
        { 'sn' => ['test_last_name'] },
        { 'givenname' => ['test_first_name'] },
        { 'telephonenumber' => [number.to_s] }
      ]

      ldap_conn = instance_double(Net::LDAP)
      allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
      expect(ldap_conn).to receive(:bind)
      expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1]).and_yield(entries[2])

      u = UCPath::User.new(ucpath_id)
      expect(u.rec.contact_info.phones.phone_number).to eq('510-645-1234')
    end
  end

  it 'handles non-primary phone number preferred attribute' do
    ucpath_id = '10000004'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.preferred).to eq('false')
  end

  it 'handles primary phone number preferred attribute' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.contact_info.phones.preferred).to eq('true')
  end

  it 'creates expected expiry date if month is < change date (7)' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

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

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

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

    # STUB LDAP:
    ldap_filter = Net::LDAP::Filter.eq('uid', ldap_id)
    ldap_params = {
      auth: { method: :simple,
              password: 'MISSING',
              username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' },
      host: 'ldap.berkeley.edu',
      port: 389
    }

    ldap_base = {
      base: 'ou=people,dc=berkeley,dc=edu',
      filter: ldap_filter
    }

    entries = [
      { 'sn' => ['test_last_name'] },
      { 'givenname' => ['test_first_name'] }
    ]

    ldap_conn = instance_double(Net::LDAP)
    allow(Net::LDAP).to receive(:new).with(ldap_params).and_return(ldap_conn)
    expect(ldap_conn).to receive(:bind)
    expect(ldap_conn).to receive(:search).with(ldap_base).and_yield(entries[0]).and_yield(entries[1])

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

end
# rubocop:enable Metrics/BlockLength
