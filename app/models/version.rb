class Version < ApplicationRecord
  include EmitsIndexChange

  belongs_to :rubygem
  has_many :dependencies, dependent: :destroy
  has_many :build_artifacts, dependent: :destroy

  validates :number, presence: true
  validates :platform, presence: true
  validates :number, uniqueness: { scope: [ :rubygem_id, :platform ] }

  scope :indexed, -> { where(indexed: true, yanked_at: nil) }
  scope :yanked,  -> { where.not(yanked_at: nil) }
  scope :release, -> { where(prerelease: false) }
end
