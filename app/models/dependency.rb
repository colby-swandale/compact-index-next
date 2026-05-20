class Dependency < ApplicationRecord
  SCOPES = %w[runtime development].freeze

  belongs_to :version
  belongs_to :rubygem, optional: true

  validates :scope, inclusion: { in: SCOPES }, allow_nil: true
end
