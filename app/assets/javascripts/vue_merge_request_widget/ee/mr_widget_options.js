import CEWidgetOptions from '../mr_widget_options';
import WidgetApprovals from './components/approvals/mr_widget_approvals';
import GeoSecondaryNode from './components/states/mr_widget_secondary_geo_node';
import RebaseState from './components/states/mr_widget_rebase';
import WidgetCodeQuality from './components/mr_widget_code_quality.vue';

export default {
  extends: CEWidgetOptions,
  components: {
    'mr-widget-approvals': WidgetApprovals,
    'mr-widget-geo-secondary-node': GeoSecondaryNode,
    'mr-widget-rebase': RebaseState,
    'mr-widget-code-quality': WidgetCodeQuality,
  },
  computed: {
    shouldRenderApprovals() {
      return this.mr.approvalsRequired;
    },
    shouldRenderCodeQuality() {
      const { codeclimate } = this.mr;
      return codeclimate && codeclimate.head_path && codeclimate.base_path;
    },
  },
  template: `
    <div class="mr-state-widget prepend-top-default">
      <mr-widget-header :mr="mr" />
      <mr-widget-pipeline
        v-if="shouldRenderPipelines"
        :mr="mr" />
      <mr-widget-deployment
        v-if="shouldRenderDeployments"
        :mr="mr"
        :service="service" />
      <mr-widget-approvals
        v-if="mr.approvalsRequired"
        :mr="mr"
        :service="service" />
      <mr-widget-code-quality
        v-if="shouldRenderCodeQuality"
        :mr="mr"
        :service="service"
        />
      <component
        :is="componentName"
        :mr="mr"
        :service="service" />
      <section
        v-if="shouldRenderRelatedLinks"
        class="mr-info-list mr-links">
        <div class="legend"></div>
        <mr-widget-related-links
          :is-merged="mr.isMerged"
          :related-links="mr.relatedLinks" />
      </section>
      <mr-widget-merge-help v-if="shouldRenderMergeHelp" />
    </div>
  `,
};
