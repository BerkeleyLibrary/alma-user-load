#!/usr/bin/env groovy

dockerComposePipeline(
  commands: [
    [run: 'rspec', entrypoint: '/bin/sh -c']
  ],
  artifacts: [
    junit   : 'artifacts/rspec/*.xml',
    html    : [
      'Code Coverage': 'coverage/',
      'RuboCop'      : 'artifacts/rubocop'
    ]
  ]
)
