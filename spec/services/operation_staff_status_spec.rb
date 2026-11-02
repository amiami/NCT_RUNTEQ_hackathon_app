require "rails_helper"

RSpec.describe OperationStaffStatus do
  let(:operation) { create(:operation) }
  let(:manager) { create(:user, :admin) }

  def add_trainee
    trainee = create(:user)
    create(:skill, user: trainee, operation: operation)
    create(:training, operation: operation, trainer: manager, trainee: trainee,
      status: :done, done_on: Date.new(2026, 10, 2))
  end

  def query_count
    queries = []
    subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] if payload[:sql].start_with?("SELECT") && payload[:name] != "SCHEMA" }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        described_class.rows(operation).each { |row| row.training&.trainer&.name }
      end
    end
    queries.size
  end

  it "人数が増えても研修の教えた人を読むクエリが増えない" do
    add_trainee
    one_person_queries = query_count
    5.times { add_trainee }
    expect(query_count).to eq(one_person_queries)
    expect(one_person_queries).to eq(4)
  end
end
