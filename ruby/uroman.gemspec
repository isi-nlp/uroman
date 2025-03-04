# frozen_string_literal: true

require_relative 'lib/uroman/version'

Gem::Specification.new do |spec|
  spec.name = 'uroman'
  spec.version = Uroman::VERSION
  spec.authors = ['Johnny Shields', 'Ulf Hermjakob']
  spec.email = %w[johnny.shields@gmail.com ulf@isi.edu]
  spec.homepage = 'https://github.com/isi-nlp/uroman'
  spec.summary = 'Universal romanizer for any script to Latin alphabet.'
  spec.description = 'Universal romanizer for any script to Latin alphabet.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0'
  spec.metadata = {
    'rubygems_mfa_required' => 'true',
    'bug_tracker_uri' => 'https://github.com/isi-nlp/uroman/issues',
    'changelog_uri' => 'https://github.com/isi-nlp/uroman/releases',
    'homepage_uri' => 'https://github.com/isi-nlp/uroman',
    'source_code_uri' => 'https://github.com/isi-nlp/uroman'
  }

  spec.add_dependency('unicode-categories')
  spec.add_dependency('unicode-name')
  spec.add_dependency('unicode-numeric_value')

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'

  spec.files = Dir.glob('lib/**/*') + %w[LICENSE.txt README.md]
  spec.bindir = 'bin'
  spec.executables = %w[uroman]
  spec.require_paths = %w[lib]
end
