<script>
import {
  GlAlert,
  GlIcon,
  GlButton,
  GlCollapsibleListbox,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlLink,
  GlSprintf,
  GlLoadingIcon,
} from '@gitlab/ui';
import { GlBreakpointInstance } from '@gitlab/ui/dist/utils';
import { uniqueId } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { visitUrl } from '~/lib/utils/url_utility';
import { s__, __, n__ } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import PipelineInputsForm from '~/ci/common/pipeline_inputs/pipeline_inputs_form.vue';
import {
  IDENTITY_VERIFICATION_REQUIRED_ERROR,
  CONFIG_VARIABLES_TIMEOUT,
  CI_VARIABLE_TYPE_FILE,
  CI_VARIABLE_TYPE_ENV_VAR,
} from '../constants';
import createPipelineMutation from '../graphql/mutations/create_pipeline.mutation.graphql';
import ciConfigVariablesQuery from '../graphql/queries/ci_config_variables.graphql';
import filterVariables from '../utils/filter_variables';
import RefsDropdown from './refs_dropdown.vue';
import VariableValuesListbox from './variable_values_listbox.vue';
import PipelineVariablesForm from './pipeline_variables_form.vue';

let pollTimeout;
export const POLLING_INTERVAL = 2000;
const i18n = {
  variablesDescription: s__(
    'Pipeline|Specify variable values to be used in this run. The variables specified in the configuration file as well as %{linkStart}CI/CD settings%{linkEnd} are used by default.',
  ),
  overrideNoteText: s__(
    'CiVariables|Variables specified here are %{boldStart}expanded%{boldEnd} and not %{boldStart}masked.%{boldEnd}',
  ),
  defaultError: __('Something went wrong on our end. Please try again.'),
  refsLoadingErrorTitle: s__('Pipeline|Branches or tags could not be loaded.'),
  submitErrorTitle: s__('Pipeline|Pipeline cannot be run.'),
  configButtonTitle: s__('Pipelines|Go to the pipeline editor'),
  warningTitle: __('The form contains the following warning:'),
  maxWarningsSummary: __('%{total} warnings found: showing first %{warningsDisplayed}'),
  removeVariableLabel: s__('CiVariables|Remove variable'),
  learnMore: __('Learn more'),
  pipelineAriaLabel: s__('Pipeline|Variable'),
};

export default {
  i18n,
  formElementClasses: 'gl-basis-1/4 gl-shrink-0 gl-flex-grow-0',
  // this height value is used inline on the textarea to match the input field height
  // it's used to prevent the overwrite if 'gl-h-7' or '!gl-h-7' were used
  textAreaStyle: { height: '32px' },
  components: {
    GlAlert,
    GlIcon,
    GlButton,
    GlCollapsibleListbox,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlLink,
    GlSprintf,
    GlLoadingIcon,
    PipelineInputsForm,
    PipelineVariablesForm,
    RefsDropdown,
    VariableValuesListbox,
    PipelineAccountVerificationAlert: () =>
      import('ee_component/vue_shared/components/pipeline_account_verification_alert.vue'),
  },
  directives: { SafeHtml },
  mixins: [glFeatureFlagsMixin()],
  props: {
    pipelinesPath: {
      type: String,
      required: true,
    },
    pipelinesEditorPath: {
      type: String,
      required: true,
    },
    canViewPipelineEditor: {
      type: Boolean,
      required: true,
    },
    defaultBranch: {
      type: String,
      required: true,
    },
    projectId: {
      type: String,
      required: true,
    },
    settingsLink: {
      type: String,
      required: true,
    },
    fileParams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    projectPath: {
      type: String,
      required: true,
    },
    refParam: {
      type: String,
      required: false,
      default: '',
    },
    variableParams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    maxWarnings: {
      type: Number,
      required: true,
    },
    isMaintainer: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      refValue: {
        shortName: this.refParam,
        // this is needed until we add support for ref type in url query strings
        // ensure default branch is called with full ref on load
        // https://gitlab.com/gitlab-org/gitlab/-/issues/287815
        fullName: this.refParam === this.defaultBranch ? `refs/heads/${this.refParam}` : undefined,
      },
      configVariablesWithDescription: {},
      form: {},
      errorTitle: null,
      error: null,
      pipelineVariables: [],
      predefinedVariables: null,
      warnings: [],
      totalWarnings: 0,
      isWarningDismissed: false,
      submitted: false,
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    ciConfigVariables: {
      fetchPolicy: fetchPolicies.NO_CACHE,
      query: ciConfigVariablesQuery,
      // Skip when variables already cached in `form` or feature flag is enabled
      skip() {
        return Object.keys(this.form).includes(this.refFullName) || this.isUsingPipelineInputs;
      },
      variables() {
        return {
          fullPath: this.projectPath,
          ref: this.refQueryParam,
        };
      },
      update({ project }) {
        return project?.ciConfigVariables;
      },
      result({ data }) {
        this.predefinedVariables = data?.project?.ciConfigVariables;

        // API cache is empty when predefinedVariables === null, so we need to
        // poll while cache values are being populated in the backend.
        // After CONFIG_VARIABLES_TIMEOUT ms have passed, we stop polling
        // and populate the form regardless.
        if (this.isFetchingCiConfigVariables && !pollTimeout) {
          pollTimeout = setTimeout(() => {
            this.predefinedVariables = [];
            this.clearPolling();
            this.populateForm();
          }, CONFIG_VARIABLES_TIMEOUT);
        }

        if (!this.isFetchingCiConfigVariables) {
          this.clearPolling();
          this.populateForm();
        }
      },
      error(error) {
        Sentry.captureException(error);
      },
      pollInterval: POLLING_INTERVAL,
    },
  },
  computed: {
    isMobile() {
      return ['sm', 'xs'].includes(GlBreakpointInstance.getBreakpointSize());
    },
    removeButtonCategory() {
      return this.isMobile ? 'secondary' : 'tertiary';
    },
    isFetchingCiConfigVariables() {
      return this.predefinedVariables === null;
    },
    isLoading() {
      return this.$apollo.queries.ciConfigVariables.loading || this.isFetchingCiConfigVariables;
    },
    isUsingPipelineInputs() {
      return this.glFeatures.ciInputsForPipelines;
    },
    overMaxWarningsLimit() {
      return this.totalWarnings > this.maxWarnings;
    },
    warningsSummary() {
      return n__('%d warning found:', '%d warnings found:', this.warnings.length);
    },
    summaryMessage() {
      return this.overMaxWarningsLimit ? i18n.maxWarningsSummary : this.warningsSummary;
    },
    shouldShowWarning() {
      return this.warnings.length > 0 && !this.isWarningDismissed;
    },
    refShortName() {
      return this.refValue.shortName;
    },
    refFullName() {
      return this.refValue.fullName;
    },
    refQueryParam() {
      return this.refFullName || this.refShortName;
    },
    variables() {
      return this.form[this.refFullName]?.variables ?? [];
    },
    descriptions() {
      return this.form[this.refFullName]?.descriptions ?? {};
    },
    identityVerificationRequiredError() {
      return this.error === IDENTITY_VERIFICATION_REQUIRED_ERROR;
    },
    variableTypeListboxItems() {
      return [
        {
          value: CI_VARIABLE_TYPE_ENV_VAR,
          text: s__('Pipeline|Variable'),
        },
        {
          value: CI_VARIABLE_TYPE_FILE,
          text: s__('Pipeline|File'),
        },
      ];
    },
  },
  methods: {
    addEmptyVariable(refValue) {
      const { variables } = this.form[refValue];

      const lastVar = variables[variables.length - 1];
      if (lastVar?.key === '' && lastVar?.value === '') {
        return;
      }

      variables.push({
        uniqueId: uniqueId(`var-${refValue}`),
        variableType: CI_VARIABLE_TYPE_ENV_VAR,
        key: '',
        value: '',
      });
    },
    clearPolling() {
      clearTimeout(pollTimeout);
      this.$apollo.queries.ciConfigVariables.stopPolling();
    },
    handleVariablesUpdated(updatedVariables) {
      this.pipelineVariables = updatedVariables;
    },
    populateForm() {
      this.configVariablesWithDescription = this.predefinedVariables.reduce(
        (accumulator, { description, key, value, valueOptions }) => {
          if (description) {
            accumulator.descriptions[key] = description;
            accumulator.values[key] = value;
            accumulator.options[key] = valueOptions;
          }

          return accumulator;
        },
        { descriptions: {}, values: {}, options: {} },
      );

      this.form = {
        ...this.form,
        [this.refFullName]: {
          descriptions: this.configVariablesWithDescription.descriptions,
          variables: [],
        },
      };

      // Add default variables from yml
      this.setVariableParams(
        this.refFullName,
        CI_VARIABLE_TYPE_ENV_VAR,
        this.configVariablesWithDescription.values,
      );

      // Add/update variables, e.g. from query string
      if (this.variableParams) {
        this.setVariableParams(this.refFullName, CI_VARIABLE_TYPE_ENV_VAR, this.variableParams);
      }

      if (this.fileParams) {
        this.setVariableParams(this.refFullName, CI_VARIABLE_TYPE_FILE, this.fileParams);
      }

      // Adds empty var at the end of the form
      this.addEmptyVariable(this.refFullName);
    },
    // eslint-disable-next-line max-params
    setVariable(refValue, type, key, value) {
      const { variables } = this.form[refValue];

      const variable = variables.find((v) => v.key === key);
      if (variable) {
        variable.type = type;
        variable.value = value;
      } else {
        variables.push({
          uniqueId: uniqueId(`var-${refValue}`),
          key,
          value,
          variableType: type,
        });
      }
    },
    setVariableAttribute(key, attribute, value) {
      const { variables } = this.form[this.refFullName];
      const variable = variables.find((v) => v.key === key);
      variable[attribute] = value;
    },
    setVariableParams(refValue, type, paramsObj) {
      Object.entries(paramsObj).forEach(([key, value]) => {
        this.setVariable(refValue, type, key, value);
      });
    },
    shouldShowValuesDropdown(key) {
      return this.configVariablesWithDescription.options[key]?.length > 1;
    },
    removeVariable(index) {
      this.variables.splice(index, 1);
    },
    canRemove(index) {
      return index < this.variables.length - 1;
    },
    async createPipeline() {
      this.submitted = true;
      try {
        const {
          data: {
            pipelineCreate: { errors, pipeline },
          },
        } = await this.$apollo.mutate({
          mutation: createPipelineMutation,
          variables: {
            input: {
              projectPath: this.projectPath,
              ref: this.refShortName,
              variables: this.isUsingPipelineInputs
                ? this.pipelineVariables
                : filterVariables(this.variables),
            },
          },
        });

        const pipelineErrors = pipeline?.errorMessages?.nodes?.map((node) => node?.content) || '';
        const totalWarnings = pipeline?.warningMessages?.nodes?.length || 0;

        if (pipeline?.path) {
          visitUrl(pipeline.path);
        } else if (errors?.length > 0 || pipelineErrors.length || totalWarnings) {
          const warnings = pipeline?.warningMessages?.nodes?.map((node) => node?.content) || '';
          const error = errors[0] || pipelineErrors[0] || '';

          this.reportError({
            title: i18n.submitErrorTitle,
            error,
            warnings,
            totalWarnings,
          });
        }
      } catch (error) {
        createAlert({ message: i18n.submitErrorTitle });
        Sentry.captureException(error);
      }

      // always re-enable submit button
      this.submitted = false;
    },
    onRefsLoadingError(error) {
      this.reportError({ title: i18n.refsLoadingErrorTitle });

      Sentry.captureException(error);
    },
    reportError({ title = null, error = i18n.defaultError, warnings = [], totalWarnings = 0 }) {
      this.errorTitle = title;
      this.error = error;
      this.warnings = warnings;
      this.totalWarnings = totalWarnings;
    },
    dismissError() {
      this.error = null;
    },
    createListItemsFromVariableOptions(key) {
      return this.configVariablesWithDescription.options[key].map((option) => ({
        text: option,
        value: option,
      }));
    },
    getPipelineAriaLabel(index) {
      return `${this.$options.i18n.pipelineAriaLabel} ${index + 1}`;
    },
  },
  learnMorePath: helpPagePath('ci/variables/_index', {
    anchor: 'cicd-variable-precedence',
  }),
};
</script>

<template>
  <gl-form @submit.prevent="createPipeline">
    <pipeline-account-verification-alert v-if="identityVerificationRequiredError" class="gl-mb-4" />
    <gl-alert
      v-else-if="error"
      :title="errorTitle"
      :dismissible="false"
      variant="danger"
      class="gl-mb-4"
    >
      <span v-safe-html="error" data-testid="run-pipeline-error-alert" class="block"></span>
      <gl-button
        v-if="canViewPipelineEditor"
        class="gl-my-3"
        data-testid="ci-cd-pipeline-configuration"
        variant="confirm"
        :aria-label="$options.i18n.configButtonTitle"
        :href="pipelinesEditorPath"
      >
        {{ $options.i18n.configButtonTitle }}
      </gl-button>
    </gl-alert>
    <gl-alert
      v-if="shouldShowWarning"
      :title="$options.i18n.warningTitle"
      variant="warning"
      class="gl-mb-4"
      data-testid="run-pipeline-warning-alert"
      @dismiss="isWarningDismissed = true"
    >
      <details>
        <summary>
          <gl-sprintf :message="summaryMessage">
            <template #total>
              {{ totalWarnings }}
            </template>
            <template #warningsDisplayed>
              {{ maxWarnings }}
            </template>
          </gl-sprintf>
        </summary>
        <p
          v-for="(warning, index) in warnings"
          :key="`warning-${index}`"
          data-testid="run-pipeline-warning"
        >
          {{ warning }}
        </p>
      </details>
    </gl-alert>
    <div class="gl-flex gl-flex-col gl-gap-4">
      <gl-form-group :label="s__('Pipeline|Run for branch name or tag')">
        <refs-dropdown
          v-model="refValue"
          :project-id="projectId"
          @loadingError="onRefsLoadingError"
        />
      </gl-form-group>

      <pipeline-inputs-form v-if="isUsingPipelineInputs" />

      <pipeline-variables-form
        v-if="isUsingPipelineInputs"
        :default-branch="defaultBranch"
        :file-params="fileParams"
        :is-maintainer="isMaintainer"
        :project-path="projectPath"
        :ref-param="refParam"
        :settings-link="settingsLink"
        :variable-params="variableParams"
        @variables-updated="handleVariablesUpdated"
      />
      <div v-else>
        <gl-loading-icon v-if="isLoading" class="gl-mb-5" size="md" />
        <gl-form-group v-else :label="s__('Pipeline|Variables')">
          <div
            v-for="(variable, index) in variables"
            :key="variable.uniqueId"
            class="gl-mb-4"
            data-testid="ci-variable-row-container"
          >
            <div class="gl-flex gl-flex-col gl-items-stretch gl-gap-4 md:gl-flex-row">
              <gl-collapsible-listbox
                :items="variableTypeListboxItems"
                :selected="variable.variableType"
                block
                fluid-width
                :aria-label="getPipelineAriaLabel(index)"
                :class="$options.formElementClasses"
                data-testid="pipeline-form-ci-variable-type"
                @select="setVariableAttribute(variable.key, 'variableType', $event)"
              />
              <gl-form-input
                v-model="variable.key"
                :placeholder="s__('CiVariables|Input variable key')"
                :class="$options.formElementClasses"
                data-testid="pipeline-form-ci-variable-key-field"
                @change="addEmptyVariable(refFullName)"
              />
              <variable-values-listbox
                v-if="shouldShowValuesDropdown(variable.key)"
                :items="createListItemsFromVariableOptions(variable.key)"
                :selected="variable.value"
                :class="$options.formElementClasses"
                class="!gl-mr-0 gl-grow"
                data-testid="pipeline-form-ci-variable-value-dropdown"
                @select="setVariableAttribute(variable.key, 'value', $event)"
              />
              <gl-form-textarea
                v-else
                v-model="variable.value"
                :placeholder="s__('CiVariables|Input variable value')"
                :style="$options.textAreaStyle"
                :no-resize="false"
                data-testid="pipeline-form-ci-variable-value-field"
              />

              <template v-if="variables.length > 1">
                <gl-button
                  v-if="canRemove(index)"
                  size="small"
                  class="gl-shrink-0"
                  data-testid="remove-ci-variable-row"
                  :category="removeButtonCategory"
                  :aria-label="$options.i18n.removeVariableLabel"
                  @click="removeVariable(index)"
                >
                  <gl-icon class="!gl-mr-0" name="remove" />
                  <span class="md:gl-hidden">{{ $options.i18n.removeVariableLabel }}</span>
                </gl-button>
                <gl-button
                  v-else
                  class="gl-invisible gl-hidden gl-shrink-0 md:gl-block"
                  icon="remove"
                  :aria-label="$options.i18n.removeVariableLabel"
                />
              </template>
            </div>
            <div v-if="descriptions[variable.key]" class="gl-text-subtle">
              {{ descriptions[variable.key] }}
            </div>
          </div>

          <template #description>
            <gl-sprintf :message="$options.i18n.variablesDescription">
              <template #link="{ content }">
                <gl-link
                  v-if="isMaintainer"
                  :href="settingsLink"
                  data-testid="ci-cd-settings-link"
                  >{{ content }}</gl-link
                >
                <template v-else>{{ content }}</template>
              </template>
            </gl-sprintf>
            <gl-link :href="$options.learnMorePath" target="_blank">{{
              $options.i18n.learnMore
            }}</gl-link>
            <div class="gl-mt-4 gl-text-subtle">
              <gl-sprintf :message="$options.i18n.overrideNoteText">
                <template #bold="{ content }">
                  <strong>
                    {{ content }}
                  </strong>
                </template>
              </gl-sprintf>
            </div>
          </template>
        </gl-form-group>
      </div>

      <div class="gl-mt-4 gl-flex">
        <gl-button
          type="submit"
          category="primary"
          variant="confirm"
          class="js-no-auto-disable gl-mr-3"
          data-testid="run-pipeline-button"
          :disabled="submitted"
          >{{ s__('Pipeline|New pipeline') }}</gl-button
        >
        <gl-button :href="pipelinesPath">{{ __('Cancel') }}</gl-button>
      </div>
    </div>
  </gl-form>
</template>
