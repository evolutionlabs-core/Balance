class AddClientReviewToEstimates < ActiveRecord::Migration[8.1]
  def change
    add_column :estimates, :lock_version, :integer, default: 0, null: false
    add_column :estimates, :client_decision, :string
    add_column :estimates, :client_decided_at, :datetime
    add_column :estimates, :client_review_snapshot, :jsonb
  end
end
