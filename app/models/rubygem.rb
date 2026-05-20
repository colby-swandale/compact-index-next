class Rubygem < ApplicationRecord
  include EmitsIndexChange

  has_many :versions, dependent: :destroy
  has_many :dependencies, through: :versions
  has_many :reverse_dependencies, class_name: "Dependency", foreign_key: :rubygem_id, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :indexed, -> { where(indexed: true) }
end
