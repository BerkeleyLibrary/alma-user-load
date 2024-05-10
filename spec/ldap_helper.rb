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

# rubocop:disable Metrics/MethodLength
def ldap_params
  {
    host: 'ldap.fake.edu',
    port: 636,
    encryption: {
      method: :simple_tls,
      tls_options: OpenSSL::SSL::SSLContext::DEFAULT_PARAMS
    },
    auth: { method: :simple,
            password: 'MISSING',
            username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu' }
  }
end
# rubocop:enable Metrics/MethodLength

def stub_ldap(id)
  ldap_rec = {}
  ldap_rec['uid'] = id
  ldap_rec['filter'] = ldap_filter(id)
  ldap_rec['params'] = ldap_params
  ldap_rec['base'] = ldap_base(ldap_rec['filter'])
  ldap_rec['connection'] = instance_double(Net::LDAP)

  ldap_rec
end
