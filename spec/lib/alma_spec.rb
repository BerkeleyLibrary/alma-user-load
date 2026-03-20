# frozen_string_literal: true

require 'spec_helper'
require 'stub_helper'
require 'tempfile'

# rubocop :disable Metrics/BlockLength
describe Alma::XMLWriter do
  before(:each) do
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
    @student_rec = SIS::Student.new user
  end

  it 'rejects an invalid file path' do
    bad_directory = Dir.mktmpdir(File.basename(__FILE__, '.rb')) { |dir| dir }
    expect(File.directory?(bad_directory)).to eq(false)
    output_path = File.join(bad_directory, 'alma.xml')
    expect { Alma::XMLWriter.open(output_path) }.to raise_error(ArgumentError)
  end

  it 'writes an Alma record to a file as XML via open class method' do
    Dir.mktmpdir(File.basename(__FILE__, '.rb')) do |dir|
      out = File.join(dir, 'test.xml')
      Alma::XMLWriter.open(out) { |w| w.write(@student_rec) }
      actual = File.read(out)
      xml = Alma::XMLBuilder.new(@student_rec).build
      expected = "<users>\n#{xml}\n</users>"
      expect(actual).to include(expected)
    end
  end

  it 'writes an Alma record to a file as XML via instance method' do
    Dir.mktmpdir(File.basename(__FILE__, '.rb')) do |dir|
      out = File.join(dir, 'test.xml')
      writer = Alma::XMLWriter.new(out)
      writer.write(@student_rec)
      writer.close
      actual = File.read(out)

      xml = Alma::XMLBuilder.new(@student_rec).build
      expected = "<users>\n#{xml}\n</users>"

      expect(actual).to include(expected)
    end
  end
end
# rubocop :enable Metrics/BlockLength

describe Alma::XMLBuilder do
  it 'creates an Alma XMLBuilder Object' do
    ucpath_id = '10000004'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id, fixture: 'active_employee_jobs.json')

    # Mock LDAP fetch and return nil for this record....
    ldap_id = '112823'
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(nil)

    user1 = UCPath::User.new(ucpath_id)

    ucpath_id = '10000007'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id, fixture: 'active_employee_jobs.json')

    # Mock fake LDAP rec to make sure we don't have an email/phone
    # for this record...
    ldap_id = '112823'
    ldap_data = Struct.new(:sn, :givenname, :berkeleyeduaffiliations, :berkeleyedualternateid, :telephonenumber, keyword_init: true)
      .new(sn: ['test_last_name'], givenname: ['test_first_name'])
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)
    user2 = UCPath::User.new(ucpath_id)

    xml = Alma::XMLBuilder.new [user1, user2]
    expect(xml).to be_kind_of(Alma::XMLBuilder)
  end
end
