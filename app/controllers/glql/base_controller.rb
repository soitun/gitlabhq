# frozen_string_literal: true

module Glql
  class BaseController < GraphqlController
    before_action :check_rate_limit, only: [:execute]

    GlqlQueryLockedError = Class.new(StandardError)

    # Overrides GraphqlController#execute to add rate limiting for GLQL queries.
    # When a query times out (raising ActiveRecord::QueryAborted), we increment the
    # Gitlab::ApplicationRateLimiter counter. If a second failure occurs within a
    # 15-minute window (configured in lib/gitlab/application_rate_limiter.rb),
    # the request is throttled. One failure is allowed, but consecutive
    # failures within the time window trigger throttling.
    def execute
      super
    rescue ActiveRecord::QueryAborted => error
      increment_rate_limit_counter

      # After incrementing the fail count with Gitlab::ApplicationRateLimiter
      # we want to re-raise ActiveRecord::QueryAborted
      # so that the existing error-handling flow continues on the frontend.
      raise error
    end

    rescue_from GlqlQueryLockedError do |exception|
      log_exception(exception)

      render_error(exception.message, status: :forbidden)
    end

    private

    def check_rate_limit
      return unless Gitlab::ApplicationRateLimiter.peek(:glql, scope: query_sha)

      raise GlqlQueryLockedError, 'Query execution is locked due to repeated failures.'
    end

    def increment_rate_limit_counter
      Gitlab::ApplicationRateLimiter.throttled?(:glql, scope: query_sha)
    end

    def query_sha
      @query_sha ||= Digest::SHA256.hexdigest(permitted_params[:query].to_s)
    end
  end
end
