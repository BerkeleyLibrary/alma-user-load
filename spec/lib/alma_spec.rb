require 'spec_helper'
require 'stub_helper'
require 'ostruct'

describe Alma::XMLBuilder do
  it 'creates an Alma XMLBuilder Object' do
    ucpath_id = '10000004'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)
    user1 = UCPath::User.new(ucpath_id)

    ucpath_id = '10000007'
    stub_ucpath_user(ucpath_id)
    stub_ucpath_jobs(ucpath_id)

    # Stub a fake LDAP rec so we make sure we don't have an email/phone
    # for this record...
    ldap_id = '112823'
    ldap_data = OpenStruct.new
    ldap_data['sn'] = ['test_last_name']
    ldap_data['givenname'] = ['test_first_name']
    allow(LDAP::API).to receive(:fetch_ldap_rec).with(ldap_id).and_return(ldap_data)
    user2 = UCPath::User.new(ucpath_id)

    xml = Alma::XMLBuilder.new [user1, user2]
    expect(xml).to be_kind_of(Alma::XMLBuilder)
  end
end
