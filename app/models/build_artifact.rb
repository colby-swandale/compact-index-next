class BuildArtifact < ApplicationRecord
  include EmitsIndexChange

  belongs_to :version

  validates :platform, :ruby_abi, :sha256, presence: true
  validates :sha256, uniqueness: true, length: { is: 64 }

  has_one :rubygem, through: :version
end
