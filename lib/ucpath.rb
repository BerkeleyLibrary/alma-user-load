require_relative 'ucpath/api'
require_relative 'ucpath/user'
require_relative '../lib/helpers/file_zip'

# UCPath runner and exporter
module UCPath
  include UCPath::API
  include Helpers::FileZip

  # rubocop :disable Metrics/MethodLength, Metrics/AbcSize
  def run_ucpath(setup)
    logger.info 'Running UCPath'
    logger.info "UCPath Request Root: #{url_root}"

    process_list = setup.users || UCPath::API.change_log(setup.start_date, setup.end_date)

    if process_list
      writer = Alma::XMLWriter.new(setup.xml_path)

      process_list.each_with_index do |id, idx|
        logger.info "#{idx} - #{id}"
        u = UCPath::User.new(id)
        writer.write(u) if u.eligible?
      end

      writer.close

      Helpers::FileZip.zipit!(setup.zip_path, setup.xml_path)
    else
      logger.info 'Warning - no records found to be processed'
    end
  end
  # rubocop :enable Metrics/MethodLength, Metrics/AbcSize
end
