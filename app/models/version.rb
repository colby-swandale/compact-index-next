class Version < ApplicationRecord
  belongs_to :rubygem
  has_many :dependencies, dependent: :destroy

  validates :number, presence: true
  validates :platform, presence: true
  validates :number, uniqueness: { scope: [ :rubygem_id, :platform ] }

  scope :indexed, -> { where(indexed: true, yanked_at: nil) }
  scope :yanked,  -> { where.not(yanked_at: nil) }
  scope :release, -> { where(prerelease: false) }
end
