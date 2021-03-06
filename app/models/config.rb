# == Schema Information
#
# Table name: configs
#
#  id            :integer          not null, primary key
#  compatibility :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  subject_id    :integer
#

class Config < ActiveRecord::Base

  # This default differs from the Confluent default of BACKWARD
  DEFAULT_COMPATIBILITY = Compatibility::Constants::BOTH
  COMPATIBILITY_NAME = 'compatibility'.freeze

  belongs_to :subject

  validates :compatibility,
            inclusion: { in: Compatibility::Constants::VALUES,
                         message: 'invalid: %{value}' },
            allow_nil: true

  def compatibility=(value)
    super(value.upcase)
  end

  def self.global
    find_or_create_by!(id: 0) do |config|
      config.compatibility = DEFAULT_COMPATIBILITY
    end
  end

  def update_compatibility!(compatibility)
    update!(compatibility: compatibility)
  rescue ActiveRecord::RecordInvalid
    if errors.key?(:compatibility)
      raise Compatibility::InvalidCompatibilityLevelError.new(compatibility)
    else
      raise
    end
  end
end
