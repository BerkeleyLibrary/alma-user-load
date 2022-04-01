require 'rubocop'
require 'rubocop/rake_task'

desc 'Run rubocop with HTML output'
RuboCop::RakeTask.new(:rubocop) do |cop|
  output = ENV['RUBOCOP_OUTPUT'] || 'artifacts/rubocop/index.html'
  puts "Writing RuboCop inspection report to #{output}"

  cop.verbose = false
  cop.formatters = ['html']
  cop.options = ['--out', output]
end

desc 'Run RuboCop with auto-correct, and output results to console'
task :ra do
  # b/c we want console output, we can't just use `rubocop:auto_correct`
  RuboCop::CLI.new.run(['--safe-auto-correct'])
end

# ------------------------------------------------------------
# Defaults

# Clear Minitest default :test tasks
%w[test test:db test:system].each { |t| Rake::Task[t].clear if Rake::Task.task_defined?(t) }

# clear rspec/rails default :spec task
Rake::Task[:default].clear if Rake::Task.task_defined?(:default)

desc 'check code style'
task default: %i[rubocop]
