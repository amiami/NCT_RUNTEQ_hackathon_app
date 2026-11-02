class ManualReviser
  class NotAdmin < StandardError; end
  class NotInternal < StandardError; end
  class StaleVersion < StandardError; end

  def self.call(user:, manual:, body:, memo:, version:)
    raise NotAdmin unless user&.admin?

    manual.with_lock do
      raise NotInternal unless manual.internal?
      raise StaleVersion unless version.to_s == manual.version.to_s

      body_before = manual.body
      manual.update!(body: body, version: manual.version + 1)
      ManualRevision.create!(manual: manual, user: user, version: manual.version,
        memo: memo, body_before: body_before, body_after: manual.body)
    end
  end
end
