# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
describe Config do
  describe '.help' do
    it 'returns help' do
      expect(Config.help).to start_with('Alma User Load Usage:')
    end
  end

  describe '.setting' do
    it 'returns change log days as 7' do
      expect(Config.setting('change_log_days')).to eq(7)
    end
  end
end

describe Config do
  describe '.skip_fte_check?' do
    let(:job_code) { 'TEST_CODE' }

    before do
      allow(Config).to receive(:check_ucpath_code).and_return(false)
    end

    context 'when job_code is in fte_check_exclusions' do
      before do
        allow(Config).to receive(:check_ucpath_code)
          .with('fte_check_exclusions', job_code)
          .and_return(true)
      end

      it 'returns true' do
        expect(Config.skip_fte_check?(job_code)).to be(true)
      end
    end

    context 'when job_code is in emeritus_job_code' do
      before do
        allow(Config).to receive(:check_ucpath_code)
          .with('emeritus_job_code', job_code)
          .and_return(true)
      end

      it 'returns true' do
        expect(Config.skip_fte_check?(job_code)).to be(true)
      end
    end

    context 'when job_code is in neither list' do
      it 'returns false' do
        expect(Config.skip_fte_check?(job_code)).to be(false)
      end
    end
  end
end

describe Config do
  describe '.skip_fte_check? (with real config values)' do
    it 'returns true for a job code in fte_check_exclusions' do
      expect(Config.skip_fte_check?('CWR016')).to be(true)
    end

    it 'returns true for a job code in emeritus_job_code' do
      expect(Config.skip_fte_check?('009902')).to be(true)
    end

    it 'returns false for a job code not in either list' do
      expect(Config.skip_fte_check?('TOTALLY_FAKE_CODE')).to be(false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
