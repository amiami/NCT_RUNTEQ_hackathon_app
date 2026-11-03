module Admin
  class ManualRevisionsController < Admin::BaseController
    def index
      # 1行ごとに作業名と種類を読むので、先にまとめて読み込んで N+1 を避ける
      @revisions = ManualRevision.newest_first.includes(manual: :operation)
    end
  end
end
