class Highrise::Person
  def self.search(term)
    find(:all, :params => {:term => term}, :from => "/people/search.xml")
  end
  
  def to_ldap_entry
		{	
		  "objectclass"     => ["top", "person", "organizationalPerson", "inetOrgPerson", "mozillaOrgPerson"],
			"uid"             => [id.to_s],
 			"sn"              => [last_name],
  		"givenName"       => [first_name],
			"cn"              => [name],
  		"title"           => [title],
  		"o"               => [company].compact.flatten.map(&:name),
  		"telephonenumber" => phone_numbers.select {|n| n.location == 'Work'}.map(&:number),
  		"homephone"       => phone_numbers.select {|n| n.location == 'Home'}.map(&:number),
  		"fax"             => phone_numbers.select {|n| n.location == 'Fax'}.map(&:number),
  		"mobile"          => phone_numbers.select {|n| n.location == 'Mobile'}.map(&:number),
  		"street"          => addresses.map(&:street),
  		"l"               => addresses.map(&:city),
  		"st"              => addresses.map(&:state), 
  		"postalcode"      => addresses.map(&:zip), 
  		"mail"            => email_addresses.map(&:address),
		}
	end
	
	def addresses
	  contact_data.addresses || []
  end
  
  def phone_numbers
    contact_data.phone_numbers || []
  end
  
  def email_addresses
    contact_data.email_addresses || []
  end
end
