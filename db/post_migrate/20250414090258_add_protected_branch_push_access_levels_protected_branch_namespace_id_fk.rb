# frozen_string_literal: true

class AddProtectedBranchPushAccessLevelsProtectedBranchNamespaceIdFk < Gitlab::Database::Migration[2.2]
  milestone '18.0'
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :protected_branch_push_access_levels, :namespaces,
      column: :protected_branch_namespace_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :protected_branch_push_access_levels, column: :protected_branch_namespace_id
    end
  end
end
