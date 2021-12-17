require 'nokogiri'

module Alma
  

  class XML

    attr_accessor :doc

    # Initizlize your XML document and create the root node
    def initialize(root = nil)
      @doc = Nokogiri::XML("<#{root}></#{root}>", nil, 'UTF-8')
    end
    

    # Create element and append it to the root of the XML doc
    def append(name, content = nil)
      element = Nokogiri::XML::Node.new(name, doc)
      element.content = content if content
      doc.root.add_child(element)
    end
    
    # Create and return a simple XML element
    def create_element(name, content = nil)
      element = Nokogiri::XML::Node.new(name, doc)
      element.content = content if content
      element
    end

    # Create element and append it to the root of the XML doc
    def append(name, content = nil)
      element = Nokogiri::XML::Node.new(name, doc)
      element.content = content if content
      doc.root.add_child(element)
    end

    # Append a given element to the root
    def append_element(element)
      doc.root.add_child(element)
    end

    # Add an attribute to a given element
    def add_attribute(element, name, value)
      element[name] = value
    end

    # Append a child element to a parent element
    def child_to_parent(child, parent)
      parent.add_child(child)
    end

    def comment(comment)
      doc.root << Nokogiri::XML::Comment.new(doc, comment)
    end

    # Create and return a simple XML element
    def create_element(name, content = nil)
      element = Nokogiri::XML::Node.new(name, doc)
      element.content = content if content
      element
    end

    # Append a child element to a parent element
    def child_to_parent(child, parent)
      parent.add_child(child)
    end

    # Functions below probably not necessary for production
    def print
      puts "------------ PRINT XML --------------"
      puts doc
      puts "-------------------------------------"
    end

    # Return the XML
    def xml
      doc
    end

  end
end




# class XmlBuilder
#   attr_accessor :doc

#   # Creates our root element <users> and returns the Nokogiri XML obj
#   def initialize
    
#     builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
#       xml.users {
#         xml.comment('start')
#       }
#     end

#     xml = builder.to_xml

#     # &:noblanks makes it all pretty
#     @doc = Nokogiri::XML(xml, &:noblanks)
#   end

#   # Create and return a node
#   def create_node(node_name)
#     Nokogiri::XML::Node.new(node_name, doc)
#   end

#   # Adds an attribute to an node/elements
#   def add_attribute(node, name, value)
#     node[name] = value
#   end

#   # Add an element to the root node
#   def add_element(node_name, content = nil)
#     new_element = Nokogiri::XML::Node.new(node_name, doc)
#     new_element.content = content if content
#     doc.root.add_child(new_element)
#   end
  
#   # create and return a simple text element
#   def create_element(name, content = nil)
#     element = Nokogiri::XML::Node.new(name, doc)
#     element.content = content if content
#     element
#   end

#   # Add an element to a node
#   def add_element_to_node(node, name, content = nil)
#     new_element = Nokogiri::XML::Node.new(name, node)
#     new_element.content = content if content
#     node.add_child(new_element)
#   end

#   # Append a node to the root node
#   def append_node(node)
#     @doc.root.add_child(node)
#   end

#   # Adds a child node to a parent node
#   def concatenate_nodes(parent, child)
#     parent.add_child(child)
#   end

#   def add_child(parent, child)
#     parent.add_child(child)
#   end

#   # Probably not necessary
#   def print
#     puts "---------- PRINT XML ------------"
#     puts doc
#     puts "--------------------------------------"
#   end

#   # Probably not necessary - but for now keeping it here handy
#   def add_comment(comment)
#     comment = Nokogiri::XML::Comment.new(doc, comment)
#     doc.root << comment
#   end


# end


# ###
# # Example User:
# # <user>
# # <record_type>PUBLIC</record_type>
# # <primary_id>10159427</primary_id>
# # <first_name>Aanika</first_name>
# # <middle_name/>
# # <last_name>Shah</last_name>
# # <full_name></full_name>
# # <user_group>FACULTY</user_group>
# # <campus_code>UCB Campus</campus_code>
# # <expiry_date>2023-10-31</expiry_date>
# # <purge_date>2023-10-31</purge_date>
# # <account_type>EXTERNAL</account_type>
# # <status>ACTIVE</status>
# # <contact_info>
# #   <addresses>
# #     <address preferred="true" segment_type="Internal">
# #       <line1>DS Educ Prgs _ Commons</line1>
# #       <line2>Barrows Hall-F03-94720</line2>
# #       <city>Berkeley</city>
# #       <state_province>CA</state_province>
# #       <postal_code>94720</postal_code>
# #       <country></country>
# #       <address_note></address_note>
# #       <start_date>2021-07-27</start_date>
# #       <end_date>2023-10-31</end_date>
# #       <address_types>
# #         <address_type>school</address_type>
# #       </address_types>
# #     </address>
# #   </addresses>
# #   <emails>
# #     <email preferred="true" segment_type="Internal">
# #       <email_address>aanika.shah@berkeley.edu</email_address>
# #       <email_types>
# #         <email_type>school</email_type>
# #       </email_types> 
# #     </email>
# #   </emails>
# #   <phones>
# #     <phone preferred="true" preferred_sms="false" segment_type="External">
# #       <phone_number>650-440-1882</phone_number>
# #       <phone_types>
# #       <phone_type>office</phone_type>
# #       </phone_types>
# #     </phone>
# #   </phones>
# # </contact_info>
# # <user_identifiers>
# #   <user_identifier segment_type="Internal">
# #     <id_type>BARCODE</id_type>
# #     <value>013228482</value>
# #     <status>ACTIVE</status>
# #   </user_identifier>
# #   <user_identifier segment_type="Internal">
# #     <id_type>BARCODE</id_type>
# #     <value>E10159427</value>
# #     <status>ACTIVE</status>
# #   </user_identifier>
# #   <user_identifier segment_type="Internal">
# #     <id_type>BARCODE</id_type>
# #     <value>A3228482</value>
# #     <status>ACTIVE</status>
# #   </user_identifier>
# #   <user_identifier segment_type="Internal">
# #     <id_type>BARCODE</id_type>
# #     <value>1557787</value>
# #     <status>ACTIVE</status>
# #   </user_identifier>
# # </user_identifiers>
# # <user_roles>
# #   <user_role>
# #     <status>NEW</status>
# #     <scope></scope>
# #     <role_type>200</role_type>
# #     <expiry_date>2023-10-31</expiry_date>
# #   </user_role>
# # </user_roles>
# # <user_statistics>
# #   <user_statistic segment_type="External">
# #     <statistic_category>UCB</statistic_category>
# #     <category_type></category_type>
# #     <statistic_note>DSDDO</statistic_note>
# #   </user_statistic>
# #   <user_statistic segment_type="External">
# #     <statistic_category>UCB</statistic_category>
# #     <category_type></category_type>
# #     <statistic_note>Faculty/Academic Staff</statistic_note>
# #   </user_statistic>
# # </user_statistics>
# # </user>