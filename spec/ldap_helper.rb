# Simple helper to stub out LDAP calls

def ldap_filter(ldap_id)
  Net::LDAP::Filter.eq('uid', ldap_id)
end

def ldap_base(filter)
  {
    base: 'ou=people,dc=berkeley,dc=edu',
    filter: filter
  }
end

def ldap_params
  {
    host: 'ldap.fake.edu',
    port: 636,
    encryption: {
      method: :simple_tls
    },
    auth: { method: :simple,
            password: 'MISSING',
            username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' }
  }
end

def stub_ldap(id)
  ldap_rec = {}
  ldap_rec['uid'] = id
  ldap_rec['filter'] = ldap_filter(id)
  ldap_rec['params'] = ldap_params
  ldap_rec['base'] = ldap_base(ldap_rec['filter'])
  ldap_rec['connection'] = instance_double(Net::LDAP)

  ldap_rec
end

def stub_ldap_entries(ldap_id, entries)
  ldap_stub = stub_ldap(ldap_id)
  ldap_conn = ldap_stub['connection']

  allow(Net::LDAP).to receive(:new).with(ldap_stub['params']).and_return(ldap_conn)
  expect(ldap_conn).to receive(:bind)
  expect(ldap_conn).to receive(:search).with(ldap_stub['base']) do |_, &block|
    entries.each { |entry| block.call(entry) }
  end

  ldap_stub
end
