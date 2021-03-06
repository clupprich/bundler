# frozen_string_literal: true
require "bundler/cli/common"

module Bundler
  class CLI::Update
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Bundler.ui.level = "error" if options[:quiet]

      Plugin.gemfile_install(Bundler.default_gemfile) if Bundler.feature_flag.plugins?

      sources = Array(options[:source])
      groups  = Array(options[:group]).map(&:to_sym)

      if gems.empty? && sources.empty? && groups.empty? && !options[:ruby] && !options[:bundler]
        # We're doing a full update
        Bundler.definition(true)
      else
        unless Bundler.default_lockfile.exist?
          raise GemfileLockNotFound, "This Bundle hasn't been installed yet. " \
            "Run `bundle install` to update and install the bundled gems."
        end
        # cycle through the requested gems, to make sure they exist
        names = Bundler.locked_gems.specs.map(&:name)
        gems.each do |g|
          next if names.include?(g)
          raise GemNotFound, Bundler::CLI::Common.gem_not_found_message(g, names)
        end

        if groups.any?
          specs = Bundler.definition.specs_for groups
          gems.concat(specs.map(&:name))
        end

        Bundler.definition(:gems => gems, :sources => sources, :ruby => options[:ruby])
      end

      Bundler::CLI::Common.config_gem_version_promoter(Bundler.definition, options)

      Bundler::Fetcher.disable_endpoint = options["full-index"]

      opts = options.dup
      opts["update"] = true
      opts["local"] = options[:local]

      Bundler.settings[:jobs] = opts["jobs"] if opts["jobs"]

      Bundler.definition.validate_runtime!
      Installer.install Bundler.root, Bundler.definition, opts
      Bundler.load.cache if Bundler.app_cache.exist?

      if Bundler.settings[:clean] && Bundler.settings[:path]
        require "bundler/cli/clean"
        Bundler::CLI::Clean.new(options).run
      end

      Bundler.ui.confirm "Bundle updated!"
      without_groups_messages
    end

  private

    def without_groups_messages
      return unless Bundler.settings.without.any?
      require "bundler/cli/common"
      Bundler.ui.confirm Bundler::CLI::Common.without_groups_message
    end
  end
end
