# frozen_string_literal: true

# RootController
#
# This controller exists solely to handle requests to `root_url`. When a user is
# logged in and has customized their `dashboard` setting, they will be
# redirected to their preferred location.
#
# For users who haven't customized the setting, we simply delegate to
# `DashboardController#show`, which is the default.
class RootController < Dashboard::ProjectsController
  skip_before_action :authenticate_user!, only: [:index]

  before_action :redirect_unlogged_user, if: -> { current_user.nil? }
  before_action :redirect_logged_user, if: -> { current_user.present? }
  # We only need to load the projects when the user is logged in but did not
  # configure a dashboard. In which case we render projects. We can do that straight
  # from the #index action.
  skip_before_action :projects

  CACHE_CONTROL_HEADER = 'no-store'

  def index
    # When your_work_projects_vue FF is enabled we load the projects via GraphQL query
    # so we don't want to preload the projects at the controller level to avoid duplicate queries.
    return if Feature.enabled?(:your_work_projects_vue, current_user)

    # n+1: https://gitlab.com/gitlab-org/gitlab-foss/issues/40260
    Gitlab::GitalyClient.allow_n_plus_1_calls do
      projects
      super
    end
  end

  private

  def redirect_unlogged_user
    redirect_path = redirect_to_home_page_url? ? Gitlab::CurrentSettings.home_page_url : new_user_session_path
    status = root_redirect_enabled? ? :moved_permanently : :found

    response.headers['Cache-Control'] = CACHE_CONTROL_HEADER if root_redirect_enabled?
    redirect_to(redirect_path, status: status)
  end

  def root_redirect_enabled?
    Gitlab::CurrentSettings.current_application_settings.root_moved_permanently_redirection
  end

  def redirect_logged_user
    case current_user.dashboard
    when 'stars'
      flash.keep
      redirect_to(starred_dashboard_projects_path)
    when 'member_projects'
      if Feature.enabled?(:your_work_projects_vue, current_user)
        flash.keep
        redirect_to(member_dashboard_projects_path)
      end
    when 'your_activity'
      redirect_to(activity_dashboard_path)
    when 'project_activity'
      redirect_to(activity_dashboard_path(filter: 'projects'))
    when 'starred_project_activity'
      redirect_to(activity_dashboard_path(filter: 'starred'))
    when 'followed_user_activity'
      redirect_to(activity_dashboard_path(filter: 'followed'))
    when 'groups'
      redirect_to(dashboard_groups_path)
    when 'todos'
      redirect_to(dashboard_todos_path)
    when 'issues'
      redirect_to(issues_dashboard_path(assignee_username: current_user.username))
    when 'merge_requests'
      redirect_to(merge_requests_dashboard_path(assignee_username: current_user.username))
    end
  end

  def redirect_to_home_page_url?
    # If user is not signed-in and tries to access root_path - redirect them to landing page
    # Don't redirect to the default URL to prevent endless redirections
    return false unless Gitlab::CurrentSettings.home_page_url.present?

    home_page_url = Gitlab::CurrentSettings.home_page_url.chomp('/')
    root_urls = [Gitlab.config.gitlab['url'].chomp('/'), root_url.chomp('/')]

    root_urls.exclude?(home_page_url)
  end
end

RootController.prepend_mod_with('RootController')
