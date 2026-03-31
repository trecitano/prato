# frozen_string_literal: true

GEM_LIST_VERSIONS = {
  "ar-5-0" => {
    activerecord: "~> 5.0.0",
    adapters: {
      sqlite3: "~> 1.3.0",
      pg: nil,
      mysql2: "~> 0.4.10"
    },
    overwrites: {
      minitest: ">= 5.15.0"
    }
  },
  "ar-5-1" => {
    activerecord: "~> 5.1.0",
    adapters: {
      sqlite3: "~> 1.4.0",
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.15.0"
    }
  },
  "ar-5-2" => {
    activerecord: "~> 5.2.0",
    adapters: {
      sqlite3: "~> 1.5.0",
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.15.0"
    }
  },
  "ar-6-0" => {
    activerecord: "~> 6.0.0",
    adapters: {
      sqlite3: "~> 1.5.0",
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.15.0"
    }
  },
  "ar-6-1" => {
    activerecord: "~> 6.1.0",
    adapters: {
      sqlite3: "~> 1.6.0",
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.25.4"
    }
  },
  "ar-7-0" => {
    activerecord: "~> 7.0.0",
    adapters: {
      sqlite3: "~> 1.7",
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.26.1"
    }
  },
  "ar-7-1" => {
    activerecord: "~> 7.1.0",
    adapters: {
      sqlite3: nil,
      pg: nil,
      mysql2: nil
    },
    overwrites: {
      minitest: ">= 5.26.1"
    }
  },
  "ar-7-2" => {
    activerecord: "~> 7.2.0",
    adapters: {
      sqlite3: nil,
      pg: nil,
      mysql2: nil
    }
  },
  "ar-8-0" => {
    activerecord: ">= 8.0.0",
    adapters: {
      sqlite3: nil,
      pg: nil,
      mysql2: nil
    }
  },
  "ar-8-1" => {
    activerecord: "~> 8.1.0",
    adapters: {
      sqlite3: nil,
      pg: nil,
      mysql2: nil
    }
  }
}.freeze

GEM_LIST_VERSIONS.each do |base_name, gem_versions|
  adapters = gem_versions[:adapters]
  active_record_version = gem_versions[:activerecord]
  overwrites = gem_versions[:overwrites]

  adapters.each do |adapter_name, adapter_version|
    appraise "#{base_name}-#{adapter_name}" do
      # Remove base gems from the gemfile
      remove_gem "appraisal"
      remove_gem "irb"
      remove_gem "rubocop"
      remove_gem "simplecov"
      remove_gem "sqlite3"

      gem "activerecord", active_record_version
      overwrites&.each do |overwrite_gem_name, overwrite_version|
        gem overwrite_gem_name.to_s, overwrite_version
      end

      if adapter_version.nil?
        gem adapter_name
      else
        gem adapter_name, adapter_version
      end
    end
  end
end
