class Training < ApplicationRecord
  belongs_to :operation
  belongs_to :trainer, class_name: "User"
  belongs_to :trainee, class_name: "User"

  # 数字は部分ユニークインデックス index_trainings_open_per_trainee の条件（status <> 2）と合わせる
  enum :status, { requested: 0, acknowledged: 1, done: 2 }, validate: true

  validates :trainee_id, uniqueness: { scope: :operation_id, conditions: -> { where.not(status: :done) } },
                         unless: :done?
  validate :trainee_must_differ_from_trainer

  private

  def trainee_must_differ_from_trainer
    errors.add(:trainee, :same_as_trainer) if trainee_id.present? && trainee_id == trainer_id
  end
end
