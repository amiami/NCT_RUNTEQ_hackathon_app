module Staff
  class ManualRevisionsController < ApplicationController
    def index
      render "shared/placeholder", locals: { title: t("navigation.staff.manual_revisions") }
    end
  end
end
