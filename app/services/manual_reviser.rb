class ManualReviser
  class NotAdmin < StandardError; end
  class StaleVersion < StandardError; end

  def self.call(user:, manual:, memo:, version:, body: nil)
    raise NotAdmin unless user&.admin?

    manual.with_lock do
      raise StaleVersion unless version.to_s == manual.version.to_s

      body_before = manual.body if manual.internal?
      manual.body = body if manual.internal?
      manual.update!(version: manual.version + 1)
      ManualRevision.create!(manual: manual, user: user, version: manual.version,
        memo: memo, body_before: body_before, body_after: manual.internal? ? manual.body : nil)
    end
  end
end
