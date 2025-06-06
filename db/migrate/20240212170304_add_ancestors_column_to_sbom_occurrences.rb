# frozen_string_literal: true

class AddAncestorsColumnToSbomOccurrences < Gitlab::Database::Migration[2.2]
  milestone '16.10'

  enable_lock_retries!

  def up
    # rubocop:disable Migration/PreventAddingColumns -- large tables
    add_column :sbom_occurrences, :ancestors, :jsonb, default: [], null: false
    # rubocop:enable Migration/PreventAddingColumns
  end

  def down
    remove_column :sbom_occurrences, :ancestors
  end
end
