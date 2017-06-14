<<<<<<< HEAD
import Vue from 'vue';
import PipelinesMediator from './pipeline_details_mediatior';
import pipelineGraph from './components/graph/graph_component.vue';
=======
/* global Flash */

import Vue from 'vue';
import PipelinesMediator from './pipeline_details_mediatior';
import pipelineGraph from './components/graph/graph_component.vue';
import pipelineHeader from './components/header_component.vue';
import eventHub from './event_hub';
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

document.addEventListener('DOMContentLoaded', () => {
  const dataset = document.querySelector('.js-pipeline-details-vue').dataset;

  const mediator = new PipelinesMediator({ endpoint: dataset.endpoint });

  mediator.fetchPipeline();

<<<<<<< HEAD
  const pipelineGraphApp = new Vue({
=======
  // eslint-disable-next-line
  new Vue({
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    el: '#js-pipeline-graph-vue',
    data() {
      return {
        mediator,
      };
    },
    components: {
      pipelineGraph,
    },
    render(createElement) {
      return createElement('pipeline-graph', {
        props: {
          isLoading: this.mediator.state.isLoading,
          pipeline: this.mediator.store.state.pipeline,
        },
      });
    },
  });

<<<<<<< HEAD
  return pipelineGraphApp;
=======
  // eslint-disable-next-line
  new Vue({
    el: '#js-pipeline-header-vue',
    data() {
      return {
        mediator,
      };
    },
    components: {
      pipelineHeader,
    },
    created() {
      eventHub.$on('headerPostAction', this.postAction);
    },
    beforeDestroy() {
      eventHub.$off('headerPostAction', this.postAction);
    },
    methods: {
      postAction(action) {
        this.mediator.service.postAction(action.path)
          .then(() => this.mediator.refreshPipeline())
          .catch(() => new Flash('An error occurred while making the request.'));
      },
    },
    render(createElement) {
      return createElement('pipeline-header', {
        props: {
          isLoading: this.mediator.state.isLoading,
          pipeline: this.mediator.store.state.pipeline,
        },
      });
    },
  });
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
});
