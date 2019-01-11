class ExtensionVersion < ApplicationRecord
  include SeriousErrors

  # Associations
  # --------------------
  has_many :extension_version_platforms
  has_many :supported_platforms, through: :extension_version_platforms
  has_many :extension_dependencies, dependent: :destroy
  has_many :extension_version_content_items, dependent: :destroy
  belongs_to :extension, required: false

  has_one_attached :source_file

  # Validations
  # --------------------
  validates :version, presence: true, uniqueness: { scope: :extension }
  validate :semantic_version

  # Leverage the +Extension+ model's default scope
  scope :active, -> { joins(:extension) }

  scope :for_architectures, ->(archs) {
    clauses = assemble_clauses(archs, 'arch')
    where(clauses.reduce(:or))
  }

  scope :for_platforms, ->(platforms) {
    clauses = assemble_clauses(platforms, 'platform')
    where(clauses.reduce(:or))
  }

  # Delegations
  # --------------------
  delegate :name, :owner, to: :extension
  delegate :name,         to: :extension, allow_nil: true, prefix: true
  delegate :hosted?,      to: :extension, allow_nil: true
  delegate :lowercase_name,to: :extension, allow_nil: true, prefix: true
  delegate :namespace,    to: :extension, allow_nil: true, prefix: true
  delegate :owner_name,   to: :extension, allow_nil: true
  delegate :github_repo,  to: :extension
  delegate :octokit,      to: :extension

  #
  # Returns the verison of the +ExtensionVersion+
  #
  # @example
  #   extension_version = ExtensionVersion.new(version: '1.0.2')
  #   extension_version.to_param # => '1.0.2'
  #
  # @return [String] the version of the +ExtensionVersion+
  #
  def to_param
    version
  end

  #
  # The total number of times this version has been downloaded
  #
  # @return [Fixnum]
  #
  def download_count
    web_download_count + api_download_count
  end

  # Create a link between a SupportedPlatform and a ExtensionVersion
  #
  # @param name [String] platform name
  # @param version [String] platform version
  #
  def add_supported_platform(name, version)
    platform = SupportedPlatform.for_name_and_version(name, version)
    ExtensionVersionPlatform.create! supported_platform: platform, extension_version: self
  end

  def download_daily_metric_key
    @download_daily_metric_key ||= "downloads.extension-#{extension_id}.version-#{id}"
  end

  def metadata
    (source_file.attached? ? source_file.metadata : nil).to_h
  end

  def release_assets
    Array.wrap(config['builds'])
      .map { |h|
        attributes = h.merge(version: self)
        ReleaseAsset.new(attributes)
      }
  end

  private

  def self.assemble_clauses(vals, config_index)
    builds = Arel::Nodes::InfixOperation.new('->',
                                             ExtensionVersion.arel_table[:config],
                                             Arel::Nodes.build_quoted('builds'))
    vals.map { |val|
      criteria = {
        :viable      => true,
        config_index => val
      }
      json = criteria.to_json
      rhs  = Arel.sql("'[#{json}]'::jsonb")
      Arel::Nodes::InfixOperation.new('@>', builds, rhs)
    }
  end

  #
  # Ensure that the version string we have been given conforms to semantic
  # versioning at http://semver.org. Also accept "master".
  #
  def semantic_version
    return true if version == "master"

    begin
      Semverse::Version.new(SemverNormalizer.call(version))
    rescue Semverse::InvalidVersionFormat
      errors.add(:version, 'is formatted incorrectly')
    end
  end
end

