module Docker
  class Secret
    class << self
      def setup_environment!(fileglob = '/run/secrets/*')
        Dir[fileglob].each do |filepath|
          puts "FP: #{filepath}"
          secret = File.read(filepath)
          secret_name = File.basename(filepath)
          ENV[secret_name] = secret unless secret.empty?
        end
      end
    end
  end

  # I Don't think I need this:
  # class << self
  #   def running_in_container?
  #     File.exist? '/.dockerenv'
  #   end
  # end
end
