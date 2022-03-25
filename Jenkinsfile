#!/usr/bin/env groovy

dockerComposePipeline(
  commands: [
    [entrypoint: 'bin/sh', command: 'rspec']
  ],
  artifacts: [
    junit   : 'artifacts/rspec/*.xml',
    html    : [
      'Code Coverage': 'coverage/',
      'RuboCop'      : 'artifacts/rubocop'
    ]
  ]
)
