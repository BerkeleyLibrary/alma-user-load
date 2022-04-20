require 'pathname'
require 'tempfile'
require 'spec_helper'

# rubocop :disable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength
describe Helpers::Setup do
  it 'creates a setup object' do
    setup = Helpers::Setup.new
    expect(setup).to be_kind_of(Helpers::Setup)
  end

  it 'accepts a type commandline arguement' do
    ARGV = ['--type', 'ucpath']
    setup = Helpers::Setup.new
    expect(setup.type).to eq('ucpath')
  end

  it 'accepts a start and end date commandline arguements' do
    ARGV = ['--type', 'ucpath',
            '--startdate', '2022-04-10',
            '--enddate', '2022-04-13']
    setup = Helpers::Setup.new
    expect(setup.start_date).to eq('2022-04-10')
    expect(setup.end_date).to eq('2022-04-13')
  end

  it 'accepts a term code as a commandline argument' do
    ARGV = ['--type', 'sis',
            '--term', '2222']
    setup = Helpers::Setup.new
    expect(setup.term_id).to eq('2222')
  end

  it 'accepts an output directory as a commanline argument' do
    ARGV = ['--type', 'sis',
            '--outdir', '/this/is/a/path']
    setup = Helpers::Setup.new
    expect(setup.outdir).to eq('/this/is/a/path')
  end

  it 'accepts a start and end date commandline arguements' do
    ARGV = ['--type', 'ucpath',
            '--startdate', '2022-04-10',
            '--enddate', '2022-04-13']
    setup = Helpers::Setup.new
    expect(setup.start_date).to eq('2022-04-10')
    expect(setup.end_date).to eq('2022-04-13')
  end

  it 'accepts --users as commandline arguement' do
    ARGV = ['--type', 'ucpath',
            '--users', '1234567']
    setup = Helpers::Setup.new
    expect(setup.users).to eq(['1234567'])
  end

  it 'accepts --help as commandline arguement' do
    ARGV << '--help'
    expect do
      expect(Helpers::Setup.new).to output(Config.help).to_stdout
    end.to raise_error(SystemExit)
  end
end
# rubocop :enable Lint/ConstantDefinitionInBlock, Style/MutableConstant, Metrics/BlockLength

describe Helpers::FileZip do
  it 'zips a file' do
    Dir.mktmpdir(File.basename(__FILE__, '.rb')) do |dir|
      # Define our file paths
      root_path = Pathname.new(dir)

      # rubocop :disable Style/StringConcatenation
      xml_path = root_path + 'test.xml'
      zip_path = root_path + 'test.zip'
      # rubocop :enable Style/StringConcatenation

      # Create our "XML" file
      File.write(xml_path, '<fake>data</fake>')

      # Zip it
      Helpers::FileZip.zipit!(zip_path, xml_path)

      # Make sure it exists and it's not empty
      zip_file = File.open(zip_path)
      expect(File.exist?(zip_file)).to eq(true)
      expect(File.size(zip_file)).to be > 0
    end
  end
end
