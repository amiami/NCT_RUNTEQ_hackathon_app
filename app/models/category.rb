class Category < ApplicationRecord
  has_many :operations, -> { order(:sort_order) }, inverse_of: :category

  validates :name, presence: true, uniqueness: true
  validates :sort_order, presence: true
end
