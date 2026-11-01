class ManualRevision < ApplicationRecord
  belongs_to :manual
  belongs_to :user

  # 改定1回につき1行。初版（第1版）の行は作らないので、版は2から
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 2 },
                      uniqueness: { scope: :manual_id }
end
