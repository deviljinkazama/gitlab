/* global Flash */

import Visibility from 'visibilityjs';
import Poll from '../lib/utils/poll';
import PipelineStore from './stores/pipeline_store';
import PipelineService from './services/pipeline_service';

export default class pipelinesMediator {
  constructor(options = {}) {
    this.options = options;
    this.store = new PipelineStore();
    this.service = new PipelineService(options.endpoint);

    this.state = {};
    this.state.isLoading = false;
  }

  fetchPipeline() {
    this.poll = new Poll({
      resource: this.service,
      method: 'getPipeline',
      successCallback: this.successCallback.bind(this),
      errorCallback: this.errorCallback.bind(this),
    });

    if (!Visibility.hidden()) {
      this.state.isLoading = true;
      this.poll.makeRequest();
<<<<<<< HEAD
=======
    } else {
      this.refreshPipeline();
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    }

    Visibility.change(() => {
      if (!Visibility.hidden()) {
        this.poll.restart();
      } else {
        this.poll.stop();
      }
    });
  }

  successCallback(response) {
    const data = response.json();

    this.state.isLoading = false;
    this.store.storePipeline(data);
  }

  errorCallback() {
    this.state.isLoading = false;
    return new Flash('An error occurred while fetching the pipeline.');
  }
<<<<<<< HEAD
=======

  refreshPipeline() {
    this.service.getPipeline()
      .then(response => this.successCallback(response))
      .catch(() => this.errorCallback());
  }
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
}
