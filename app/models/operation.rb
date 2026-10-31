class Operation < ApplicationRecord
  belongs_to :category
  has_one :manual, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :category_id }
  validates :sort_order, presence: true
end
