<script>
import { GlAlert } from '@gitlab/ui';
import MergeRequestsWidget from './merge_requests_widget.vue';
import WorkItemsWidget from './work_items_widget.vue';
import ActivityWidget from './activity_widget.vue';
import RecentlyViewedWidget from './recently_viewed_widget.vue';
import TodosWidget from './todos_widget.vue';

export default {
  components: {
    GlAlert,
    MergeRequestsWidget,
    WorkItemsWidget,
    ActivityWidget,
    TodosWidget,
    RecentlyViewedWidget,
  },
  props: {
    reviewRequestedPath: {
      type: String,
      required: true,
    },
    assignedMergeRequestsPath: {
      type: String,
      required: true,
    },
    assignedWorkItemsPath: {
      type: String,
      required: true,
    },
    authoredWorkItemsPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasMergeRequestsMetadataError: false,
    };
  },
};
</script>

<template>
  <div>
    <h1>{{ __("Today's highlights") }}</h1>
    <div class="gl-grid gl-grid-cols-1 gl-gap-6 md:gl-grid-cols-3">
      <div class="gl-flex gl-flex-col gl-gap-4 md:gl-col-span-2">
        <gl-alert
          v-if="hasMergeRequestsMetadataError"
          variant="warning"
          data-testid="merge-requests-fetch-metadata-error"
          @dismiss="hasMergeRequestsMetadataError = false"
          >{{
            s__(
              'Homepage|The number of merge requests is not available. Please refresh the page to try again.',
            )
          }}</gl-alert
        >
        <div class="gl-grid gl-grid-cols-1 gl-gap-5 lg:gl-grid-cols-2">
          <merge-requests-widget
            :review-requested-path="reviewRequestedPath"
            :assigned-to-you-path="assignedMergeRequestsPath"
            @fetch-metadata-error="hasMergeRequestsMetadataError = true"
          />
          <work-items-widget
            :assigned-to-you-path="assignedWorkItemsPath"
            :authored-by-you-path="authoredWorkItemsPath"
          />
        </div>
        <todos-widget />
        <activity-widget />
      </div>
      <div>
        <recently-viewed-widget />
      </div>
    </div>
  </div>
</template>
