require 'spec_helper'
require 'stub_helper'
require 'ostruct'

describe UCPath::API do
  it 'creates a change log' do

    s = '2021-01-01'
    e = '2021-01-03'

    stub_change_log(s, e, 'change_log_1')
    change_log(s, e)

  end
end

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
    
    # TODO - move this to stub_helper
    ldap_data = OpenStruct.new
    ldap_data['berkeleyeduaffiliations'] = ["STUDENT-TYPE-REGISTERED"]
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)

    u = UCPath::User.new(ucpath_id)
    expect(u.is_eligible?).to be(false)
  end

  it 'uses names from ldap if missing names in ucpath record' do
    ucpath_id = '12345678'
    ldap_id = '1628831'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # TODO - move to stub_helper
    ldap_data = OpenStruct.new
    ldap_data['sn'] = ['test_last_name']
    ldap_data['givenname'] = ['test_first_name']

    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.first_name).to eq('test_first_name')
    expect(u.rec.last_name).to eq('test_last_name')
  end

  it 'marks job ineligible if hr_status_code is not "A"' do
    ucpath_id = '10000003'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    u = UCPath::User.new(ucpath_id)
    expect(u.is_eligible?).to be(false)
  end

  # Collapse these into a single array driven test
  it 'sets user group libstaff' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => "000118"
      }
    )

    u = UCPath::User.new(ucpath_id)

    expect(u.rec.user_group).to eq('LIBSTAFF')
  end

  it 'sets user group UCBVISSCHOL' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => "CWR003"
      }
    )

    u = UCPath::User.new(ucpath_id)

    expect(u.rec.user_group).to eq('UCBVISSCHOL')
  end

  it 'sets user group UCEXT' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)

    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => 'dummycode',
        "dept_code" => "EXADM",
        "classification_indc" => 'A'
      }
    )
    
    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('UCEXT')
  end
  
  it 'sets user group FACULTY' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)
    
    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => '001132'
      }
    )
    
    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('FACULTY')
  end
  
  it 'sets user group EXECUTIVE' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)
    
    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => 'dummycode',
        'dept_code' => 'dummycode',
        "classification_indc" => '2'
      }
    )

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('EXECUTIVE')
  end

  it 'sets user group NONACAD' do
    ucpath_id = '10527060'
    stub_ucpath_user(ucpath_id)
    
    stub_ucpath_jobs_test(ucpath_id, 
      {
        "job_code" => 'dummycode',
        'dept_code' => 'dummycode',
        "classification_indc" => 'dummycode'
      }
    )

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.user_group).to eq('NONACAD')
  end

  it 'uses the ldap phone number' do
    ucpath_id = '12345678'
    ldap_id = '1628831'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # TODO - move to stub_helper
    ldap_data = OpenStruct.new
    ldap_data['sn'] = ['test_last_name']
    ldap_data['givenname'] = ['test_first_name']
    ldap_data['telephonenumber'] = ['925-555-1234']

    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)

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
  
      ldap_data = OpenStruct.new
      ldap_data['sn'] = ['test_last_name']
      ldap_data['givenname'] = ['test_first_name']
      ldap_data['telephonenumber'] = ["#{number}"]
  
      allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)
  
      u = UCPath::User.new(ucpath_id)
      expect(u.rec.contact_info.phones.phone_number).to eq('510-645-1234')
    end
  end

  it 'handles non-primary phone number preferred attribute' do
      ucpath_id = '10000004'
      ldap_id = '112823'
      stub_ucpath_user(ucpath_id)
      stub_ucpath_jobs(ucpath_id)
  
      ldap_data = OpenStruct.new
      ldap_data['sn'] = ['test_last_name']
      ldap_data['givenname'] = ['test_first_name']
  
      allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)
  
      u = UCPath::User.new(ucpath_id)
      expect(u.rec.contact_info.phones.preferred).to eq('false')
  end

  it 'handles primary phone number preferred attribute' do
      ucpath_id = '10000005'
      ldap_id = '112823'
      stub_ucpath_user(ucpath_id)
      stub_ucpath_jobs(ucpath_id)
  
      ldap_data = OpenStruct.new
      ldap_data['sn'] = ['test_last_name']
      ldap_data['givenname'] = ['test_first_name']
  
      allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)
  
      u = UCPath::User.new(ucpath_id)
      expect(u.rec.contact_info.phones.preferred).to eq('true')
  end

  it 'creates expected expiry date if month is < change date (7)' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    ldap_data = OpenStruct.new
    ldap_data['sn'] = ['test_last_name']
    ldap_data['givenname'] = ['test_first_name']
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)

    current_year = Date.today.year
    expiration_year = current_year + 1
    fake_month = 6
    allow(Date).to receive(:today).and_return Date.new(current_year,fake_month,1)

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.expiry_date).to eq("#{expiration_year}-10-31")
  end

  it 'creates expected expiry date if month is >= change date (7)' do
    ucpath_id = '10000005'
    ldap_id = '112823'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    ldap_data = OpenStruct.new
    ldap_data['sn'] = ['test_last_name']
    ldap_data['givenname'] = ['test_first_name']
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)

    current_year = Date.today.year
    expiration_year = current_year + 2
    fake_month = 8
    allow(Date).to receive(:today).and_return Date.new(current_year,fake_month,1)

    u = UCPath::User.new(ucpath_id)
    expect(u.rec.expiry_date).to eq("#{expiration_year}-10-31")
  end

  it 'logs an error if the ucpath record is missing a required field' do
    id = '10000006'
    stub_ucpath_user(id)
    stub_ucpath_jobs(id)
    
    u = UCPath::User.new(id)
    expect(u.errors).to include("#{id} - Missing required field: ucpath_employee_id")
  end
  
end

__END__

Sample LDAP OStruct
<OpenStruct dn=["uid=1628831,ou=people,dc=berkeley,dc=edu"], objectclass=["top", "eduPerson", "inetOrgPerson", "berkeleyEduPerson", "organizationalPerson", "person", "ucEduPerson"], ou=["people"], berkeleyeduaffiliations=["AFFILIATE-TYPE-VOLUNTEER", "EMPLOYEE-TYPE-ACADEMIC"], givenname=["Mahsa"], displayname=["Mahsa Derakhshan"], berkeleyeduconfidentialflag=["false"], sn=["Derakhshan"], berkeleyeduhcmid=["013139999"], cn=["Derakhshan, Mahsa"], uid=["1628831"], berkeleyeduucpathid=["10527060"], berkeleyeduprimarydeptunit=["SMTOC"], departmentnumber=["SMTOC"], employeenumber=["10527060"], berkeleyeduunithrdeptname=["Simons Institute TOC"], mail=["derakhshan@berkeley.edu"], berkeleyeduofficialemail=["derakhshan@berkeley.edu"], berkeleyeduemailrelflag=["FALSE"]>

<OpenStruct 
  dn=["uid=1628831,ou=people,dc=berkeley,dc=edu"], 
  objectclass=["top", "eduPerson", "inetOrgPerson", "berkeleyEduPerson", "organizationalPerson", "person", "ucEduPerson"], 
  ou=["people"], 
  berkeleyeduaffiliations=["AFFILIATE-TYPE-VOLUNTEER", "EMPLOYEE-TYPE-ACADEMIC"], 
  givenname=["Mahsa"], 
  displayname=["Mahsa Derakhshan"], 
  berkeleyeduconfidentialflag=["false"], 
  sn=["Derakhshan"], 
  berkeleyeduhcmid=["013139999"], 
  cn=["Derakhshan, Mahsa"], 
  uid=["1628831"], 
  berkeleyeduucpathid=["10527060"], 
  berkeleyeduprimarydeptunit=["SMTOC"], 
  departmentnumber=["SMTOC"], 
  employeenumber=["10527060"], 
  berkeleyeduunithrdeptname=["Simons Institute TOC"], 
  mail=["derakhshan@berkeley.edu"],
  berkeleyeduofficialemail=["derakhshan@berkeley.edu"], 
  berkeleyeduemailrelflag=["FALSE"]
>