class Category < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :sort_order, presence: true
end
