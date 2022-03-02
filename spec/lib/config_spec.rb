# frozen_string_literal: true

describe Config do
  it 'help returns help' do
    expect(Config.help).to start_with('Alma User Load Usage:')
  end

  it 'config setting for change log days is 14' do
    expect(Config.setting('change_log_days')).to eq(14)
  end
end
