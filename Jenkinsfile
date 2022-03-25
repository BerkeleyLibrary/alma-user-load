#!/usr/bin/env groovy

dockerComposePipeline(
  commands: [
    'rspec',
    'rubocop'
  ],
  artifacts: [
    junit   : 'artifacts/rspec/**/*.xml',
    html    : [
      'Code Coverage': 'coverage/',
      'RuboCop'      : 'artifacts/rubocop'
    ]
  ]
)
