require 'nokogiri'

module Alma
# I'll need to set this up to have a class for XML and a class for XML Fragment
  class XMLFragment
    attr_accessor :doc

    # Append a child node to a parent node
    def self.child_to_parent(child, parent)
      parent.add_child(child)
    end

    def initialize
      # Create an XML Doc Fragment 
      # (We'll build up a user and then stuff into the XML document)
      @doc = Nokogiri::XML::DocumentFragment.parse ''
    end

    # Create and return a simple XML element
    def create_element(name, content = nil)
      element = Nokogiri::XML::Node.new(name, doc)
      element.content = content if content
      element
    end

    # Add a chid node to the XML Fragment (aka @doc)
    def append(child)
      doc.add_child(child)
    end

    

    # Create an element and append it as a child to the parent
    def add_element(parent, name, content = nil)
      new_element = Nokogiri::XML::Node.new(name, doc)
      new_element.content = content if content
      parent.add_child(new_element)
    end

    # def append(element)
    #   doc.add_child(element)
    # end

    # Functions below probably not necessary for production
    def print
      puts "------------ PRINT XML --------------"
      puts doc
      puts "-------------------------------------"
    end
    
    def xml
      doc
    end



  end
end
