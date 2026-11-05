class ManualReviser
  class NotAdmin < StandardError; end
  class StaleVersion < StandardError; end
  class InvalidInput < StandardError; end

  def self.call(user:, manual:, memo:, version:, body: nil)
    raise NotAdmin unless user&.admin?

    manual.with_lock do
      raise StaleVersion unless version.to_s == manual.version.to_s
      raise InvalidInput, "revision_memo_required" if memo.blank?

      if manual.internal?
        body = body.to_s.gsub(/\r\n?/, "\n")
        raise InvalidInput, "revision_body_unchanged" if body == manual.body.to_s.gsub(/\r\n?/, "\n")
      end

      body_before = manual.body if manual.internal?
      manual.body = body if manual.internal?
      manual.update!(version: manual.version + 1)
      ManualRevision.create!(manual: manual, user: user, version: manual.version,
        memo: memo, body_before: body_before, body_after: manual.internal? ? manual.body : nil)
    end
  end
end
