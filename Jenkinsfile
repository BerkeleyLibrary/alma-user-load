#!/usr/bin/env groovy

dockerComposePipeline(
  commands: [
    [run: 'rspec', entrypoint: '/bin/sh -c'],
    [run: 'rake rubocop', entrypoint: '/bin/sh -c']
  ],
  artifacts: [
    junit   : 'artifacts/rspec/*.xml',
    html    : [
      'Code Coverage': 'artifacts/rcov',
      'RuboCop'      : 'artifacts/rubocop'
    ]
  ]
)
