module Featurable
  extend ActiveSupport::Concern

  QUERY_MODE = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze

  # `feature_flags` is a SIGNED bigint, so it can address at most 63 flags
  # (bits 1..63; all-enabled == 2^63-1, the in-range maximum). A 64th flag would
  # need bit 2^63 and overflow. Once the feature list exceeds 63 entries, the
  # overflow features live in additional bigint columns. The partition is by the
  # feature's 1-based index, so columns 1..63 keep their historical bit positions
  # (no data migration), and bit numbering RESTARTS at 1 in each extra column.
  FEATURES_PER_COLUMN = 63

  FEATURE_COLUMN_NAMES = %w[feature_flags feature_flags_extended].freeze

  # => { 'feature_flags' => { 1 => :feature_inbound_emails, ... 63 => :... },
  #      'feature_flags_extended' => { 1 => :feature_advanced_assignment, ... } }
  FEATURES_BY_COLUMN = FEATURE_LIST.each_with_object({}).with_index do |(feature, result), zero_based_index|
    index = zero_based_index + 1 # 1-based; equals the historical bit on feature_flags
    column = FEATURE_COLUMN_NAMES.fetch((index - 1) / FEATURES_PER_COLUMN)
    bit = ((index - 1) % FEATURES_PER_COLUMN) + 1
    (result[column] ||= {})[bit] = "feature_#{feature['name']}".to_sym
  end

  included do
    include FlagShihTzu

    FEATURES_BY_COLUMN.each do |column, flags|
      has_flags flags.merge(column: column).merge(QUERY_MODE)
    end

    before_create :enable_default_features
  end

  def enable_features(*names)
    names.each do |name|
      send("feature_#{name}=", true)
    end
  end

  def enable_features!(*names)
    enable_features(*names)
    save
  end

  def disable_features(*names)
    names.each do |name|
      send("feature_#{name}=", false)
    end
  end

  def disable_features!(*names)
    disable_features(*names)
    save
  end

  def feature_enabled?(name)
    send("feature_#{name}?")
  end

  def all_features
    FEATURE_LIST.pluck('name').index_with do |feature_name|
      feature_enabled?(feature_name)
    end
  end

  def enabled_features
    all_features.select { |_feature, enabled| enabled == true }
  end

  def disabled_features
    all_features.select { |_feature, enabled| enabled == false }
  end

  private

  def enable_default_features
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return true if config.blank?

    features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name)
    enable_features(*features_to_enabled)
  end
end
