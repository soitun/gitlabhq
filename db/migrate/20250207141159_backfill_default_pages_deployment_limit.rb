# frozen_string_literal: true

class BackfillDefaultPagesDeploymentLimit < Gitlab::Database::Migration[2.2]
  restrict_gitlab_migration gitlab_schema: :gitlab_main
  milestone '17.9'

  def up
    create_or_update_plan_limit('active_versioned_pages_deployments_limit_by_namespace', 'default', 1000)
  end

  def down
    create_or_update_plan_limit('active_versioned_pages_deployments_limit_by_namespace', 'default', 0)
  end
end
