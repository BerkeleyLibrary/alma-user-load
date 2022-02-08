describe Config do
  it 'help returns help' do
    expect(Config.help).to start_with('Alma User Load Usage:')
  end
end
