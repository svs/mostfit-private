source :rubygems

# Dependencies are generated using a strict version. Don't forget to edit the
# dependency versions when upgrading.

merb_gems_version = '~> 1.1'
merb_related_gems = '~> 1.1'
dm_gems_version   = '~> 1.2'

# Merb
gem 'merb-core',                merb_gems_version
gem 'merb-assets',              merb_gems_version
gem 'merb-helpers',             merb_gems_version
gem 'merb-mailer',              merb_gems_version
gem 'merb-slices',              merb_gems_version
gem 'merb-param-protection',    merb_gems_version
gem 'merb-exceptions',          merb_gems_version
gem 'merb-gen',                 merb_gems_version

# Merb authentication
gem 'merb-auth-core',           merb_related_gems
gem 'merb-auth-more',           merb_related_gems
gem 'merb-auth-slice-password', merb_related_gems

# Other Merb plugins
gem 'merb-haml',                merb_gems_version
gem 'merb_datamapper',          merb_gems_version

# DataMapper (or ORM)
gem 'dm-core',                  dm_gems_version
gem 'dm-aggregates',            dm_gems_version
gem 'dm-migrations',            dm_gems_version
gem 'dm-timestamps',            dm_gems_version
gem 'dm-types',                 dm_gems_version
gem 'dm-validations',           dm_gems_version
gem 'dm-serializer',            dm_gems_version
gem 'dm-transactions',          dm_gems_version
gem 'dm-mysql-adapter',         dm_gems_version

# DataMapper plugins
gem 'dm-paperclip'
gem 'dm-pagination'
gem 'dm-observer',              dm_gems_version
gem 'dm-is-tree',               dm_gems_version

# DataMapper plugin providing access to validation errors of associated parent and children objects. See the example below to get an idea on how it works.
# gem 'dm-validations-ext'

# Other gems
gem 'sequel'
gem 'mysql'
gem 'i18n',                     '~> 0.6'
gem 'i18n-translators-tools',   '~> 0.2', :require => 'i18n-translate'
gem 'htmldoc'
gem 'uuid'
gem 'builder'
gem 'gettext'
gem 'tlsmail'
gem 'cronedit'
gem 'colored'
gem 'log4r'
gem 'rake',                     '~> 0.9'
gem 'dalli'
gem 'ice_cube'
gem 'thermostat', :git => 'git://github.com/svs/thermostat.git'
gem 'hirb'

# PDF functionality should be ported to Prawn, pdf-writer is no longer maintained.
# We use this fork because it contains fixes for ruby 1.9
gem 'pdf-writer',               :git => "git://github.com/metaskills/pdf-writer.git"

# Additional dependencies of the Mostfit Maintainer slice:
gem 'dm-sqlite-adapter',        dm_gems_version
gem 'git',                      '~> 1.2'

# We use Phusion's Passenger by default, both for development and deployment.
# NOTE: When running `passenger start` for the first time it installs itself.
#       More info on this is found in `INSTALL.md`.
gem 'passenger',                '~> 3.0'

# The following gems do not currently (jan'12) work with ruby-1.9.3-head.
# They should be pre-installed as detailed in `INSTALL.md`.
gem 'debugger'

group :development do
  gem 'rspec',                  '~> 1.3'
  gem 'factory_girl',           '~> 2.3'
  gem 'spork',                  '~> 1.0rc'

  # Vlad is our deployment agent, only required by rake.
  gem 'vlad',                   :require => false
  gem 'vlad-git',               :require => false
end

