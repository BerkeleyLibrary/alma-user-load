# frozen_string_literal: true

require 'spec_helper'
require 'stub_helper'
require 'ostruct'
require 'nokogiri'

# rubocop :disable Lint/ConstantDefinitionInBlock, Style/MutableConstant
describe SIS do
  it 'runs sis' do
    allow(Date).to receive(:today).and_return Date.new(2022, 5, 31)

    term_id = '2222'
    stub_past_sis_data(term_id, '2022-04-10', 1)
    stub_past_sis_data(term_id, '2022-04-10', 2)
    stub_sis_data(term_id, 1)
    stub_sis_data(term_id, 2)

    Dir.mktmpdir do |dir|
      outpath = Pathname.new(dir)

      ARGV = ['--type', 'sis', '-s', '2022-04-10', '--term', '2222', '--outdir', outpath]
      setup = Helpers::Setup.new
      SIS.run_sis setup

      expect(File.exist?(setup.zip_path)).to eq(true)
      expect(File.read(setup.xml_path)).to eq(File.read('spec/data/sis/expected_xml_3.xml'))
    end
  end
end
# rubocop :enable Lint/ConstantDefinitionInBlock, Style/MutableConstant

# rubocop:disable Metrics/BlockLength
describe SIS::API do
  it 'fetches students by term' do
    term_id = '2222'
    stub_sis_data(term_id, 1)
    stub_sis_data(term_id, 2)

    users = SIS::API.fetch_by_term(term_id)

    expect(users.count).to eq(2)
  end

  it 'returns the correct term code for summer term' do
    allow(Date).to receive(:today).and_return Date.new(2022, 6, 15)
    expected_term = '2225'
    current_term = SIS::API.current_term
    expect(current_term).to eq(expected_term)
  end

  it 'returns the correct term code for fall term' do
    allow(Date).to receive(:today).and_return Date.new(2022, 11, 15)
    expected_term = '2228'
    current_term = SIS::API.current_term
    expect(current_term).to eq(expected_term)
  end

  it 'returns the correct term code for spring term' do
    allow(Date).to receive(:today).and_return Date.new(2022, 4, 15)
    expected_term = '2222'
    current_term = SIS::API.current_term
    expect(current_term).to eq(expected_term)
  end

  it 'returns empty array after multiple failed attempts' do
    term_id = '2222'
    stub_request(:get, 'https://apis.berkeley.edu/sis/v2/students?inc-acad=true&inc-cntc=true&inc-regs=true&page-number=1&page-size=100&term-id=2222')
      .to_raise('fake error')

    u = SIS::API.fetch_by_term(term_id)
    expect(u).to eq([])
  end
end

describe SIS::Student do
  it 'is a SIS Student Object' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Tony',
      'prim_name_familyname' => 'Stark',
      'acadcareer_code' => 'GRAD'
    }
    student = SIS::Student.new user

    expect(student).to be_kind_of(Student)
  end

  it 'sets the local address' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'locl_address_address1' => '1234 Avengers Plaza',
      'locl_address_address2' => 'Appt. 2',
      'locl_address_city' => 'New York',
      'locl_address_statecode' => 'NY',
      'locl_address_postalcode' => '10001'
    }
    student = SIS::Student.new user

    expect(student.rec.contact_info.addresses[0].address_types).to eq('school')
  end

  it 'sets the home address' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'home_address_address1' => '413 Palace Place',
      'home_address_address2' => '#3',
      'home_address_city' => 'Asgard',
      'home_address_statecode' => 'Midgard',
      'home_address_postalcode' => '000001'
    }
    student = SIS::Student.new user

    expect(student.rec.contact_info.addresses[0].address_types).to eq('home')
  end

  it 'can be built into <user> XML element' do

    allow(Date).to receive(:today).and_return Date.new(2022, 5, 31)

    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'home_address_address1' => '413 Palace Place',
      'home_address_address2' => '#3',
      'home_address_city' => 'Asgard',
      'home_address_statecode' => 'Midgard',
      'home_address_postalcode' => '000001',
      'email_emailaddress' => 'pointbreak@avengers.org',
      'phone_number' => '555-333-1234'
    }

    student = SIS::Student.new user
    xml_rec = Alma::XMLBuilder.new(student).build

    expect(xml_rec.to_xml).to eq(File.read('spec/data/sis/expected_xml_1.xml'))
  end

  it 'can be built into <user> XML element without email/phone' do

    allow(Date).to receive(:today).and_return Date.new(2022, 5, 31)

    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'home_address_address1' => '413 Palace Place',
      'home_address_address2' => '#3',
      'home_address_city' => 'Asgard',
      'home_address_statecode' => 'Midgard',
      'home_address_postalcode' => '000001'
    }

    student = SIS::Student.new user
    xml_rec = Alma::XMLBuilder.new(student).build

    expect(xml_rec.to_xml).to eq(File.read('spec/data/sis/expected_xml_2.xml'))
  end

  it 'sets the phone' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'phone_number' => '925.555.1234'
    }
    student = SIS::Student.new user

    expect(student.rec.contact_info.phones.phone_number).to eq('925-555-1234')
  end

  it 'does not format phone numbers where the pattern is not recognized' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'phone_number' => '123456789101112'
    }
    student = SIS::Student.new user

    expect(student.rec.contact_info.phones.phone_number).to eq('123456789101112')
  end

  it 'handles all known mangled telephone formats' do
    known_phone_formats = [
      '510 645-1234',
      '5106451234',
      '645-1234',
      '5-1234'
    ]

    known_phone_formats.each do |number|
      user = {
        'student_id' => '12345',
        'prim_name_givenname' => 'Thor',
        'prim_name_familyname' => 'Odinson',
        'acadcareer_code' => 'GRAD',
        'phone_number' => number
      }
      student = SIS::Student.new user

      expect(student.rec.contact_info.phones.phone_number).to eq('510-645-1234')
    end
  end

  it 'sets expiry date to default if student not withcncl and month not May, Aug, Dec' do
    allow(Date).to receive(:today).and_return Date.new(2022, 1, 15)
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD'
    }

    student = SIS::Student.new user
    expected_expiry_date = '2023-10-31'
    expect(student.rec.expiry_date).to eq(expected_expiry_date)
  end

  it 'sets expiry date to today if student cancelled registration and month not May, Aug, Dec' do
    allow(Date).to receive(:today).and_return Date.new(2022, 1, 15)
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'withcncl' => 'CAN'
    }
    student = SIS::Student.new user
    expected_expiry_date = Date.today.to_s
    expect(student.rec.expiry_date).to eq(expected_expiry_date)
  end

  it 'sets expiry date to default if student cancelled registration within month May, Aug, Dec' do
    allow(Date).to receive(:today).and_return Date.new(2022, 12, 15)
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD',
      'withcncl' => 'CAN'
    }
    student = SIS::Student.new user
    expected_expiry_date = '2024-10-31'
    expect(student.rec.expiry_date).to eq(expected_expiry_date)
  end

  it 'sets expiry date to 10-31-xxxx if student is registration' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Thor',
      'prim_name_familyname' => 'Odinson',
      'acadcareer_code' => 'GRAD'
    }

    current_year = Date.today.year
    cr_plus2 = current_year + 2
    allow(Date).to receive(:today).and_return(Date.parse("#{current_year}-08-31"))
    student = SIS::Student.new user
    expect(student.rec.expiry_date).to eq("#{cr_plus2}-10-31")
  end

  it 'sets the user group' do
    # Let's test all of the user groups:
    user_group_map = {
      'GRAD' => 'GRADSTUD',
      'LAW' => 'GRADSTUD',
      'UCBX' => 'UCEXTSTUD',
      'UGRD' => 'UNDERGRAD',
      'UNKNOWN' => 'UNKNOWN'
    }

    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Tony',
      'prim_name_familyname' => 'Stark'
    }

    user_group_map.each do |key, value|
      user['acadcareer_code'] = key
      student = SIS::Student.new user
      expect(student.rec.user_group).to eq(value)
    end
  end
end
# rubocop:enable Metrics/BlockLength
