#!/usr/bin/env groovy

@Library('jenkins-workflow-scripts@DEV-696') _

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
