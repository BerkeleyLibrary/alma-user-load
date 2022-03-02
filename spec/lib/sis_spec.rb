# frozen_string_literal: true

require 'spec_helper'
require 'stub_helper'
require 'ostruct'
require 'nokogiri'

describe SIS::API do
  it 'fetches students by term' do
    term_id = '2222'
    stub_sis_data(term_id, 1)
    stub_sis_data(term_id, 2)

    users = SIS::API.fetch_by_term(term_id)

    expect(users.count).to eq(1)
  end

  it 'returns the current term' do
    term = '2222'
    current_term = SIS::API.current_term

    expect(current_term).to eq(term)
  end
end

# rubocop:disable Metrics/BlockLength
describe SIS::Student do
  it 'is a SIS Student Object and is eligible by default' do
    user = {
      'student_id' => '12345',
      'prim_name_givenname' => 'Tony',
      'prim_name_familyname' => 'Stark',
      'acadcareer_code' => 'GRAD'
    }
    student = SIS::Student.new user

    expect(student.eligible?).to eq(true)
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

  it 'can be built into XML' do
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

    # TODO: fix this... need to set expected xml expiry_date and purge date
    #       dynamically. Since these will change depending on the time of year.
    # +    <expiry_date>2023-10-31</expiry_date>
    # +    <purge_date>2024-10-31</purge_date>

    student = SIS::Student.new user
    builder = Alma::XMLBuilder.new [student]

    expect(builder.doc.to_xml).to eq(File.read('spec/data/sis/expected_xml.xml'))
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

  it 'sets the user group' do
    # Let's test all of the user groups:
    user_group_map = {
      'GRAD' => 'GRADSTUD',
      'LAW' => 'GRADSTUD',
      'UCBX' => 'UCBX',
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
