require 'zip'

module Helpers
  module FileZip
    def zipit!(zip_path, xml_path)
      xml_filename = xml_path.basename

      Zip::File.open(zip_path, create: true) do |arc|
        arc.add(xml_filename, xml_path)
        logger.info "File Zipped: #{zip_path}"
      end
    end
  end
end
