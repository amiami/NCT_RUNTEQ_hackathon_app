module Admin
  class ManualRevisionsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.admin.manual_revisions") }
    end
  end
end
