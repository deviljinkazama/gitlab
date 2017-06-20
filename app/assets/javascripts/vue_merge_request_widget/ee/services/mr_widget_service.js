import Vue from 'vue';

import CEWidgetService from '../../services/mr_widget_service';

export default class MRWidgetService extends CEWidgetService {
  constructor(mr) {
    super(mr);

    this.approvalsResource = Vue.resource(mr.approvalsPath);
    this.rebaseResource = Vue.resource(mr.rebasePath);
  }

  approveMergeRequest() {
    return this.approvalsResource.save()
      .then(res => res.json());
  }

  unapproveMergeRequest() {
    return this.approvalsResource.delete()
      .then(res => res.json());
  }

  rebase() {
    return this.rebaseResource.save();
  }

  fetchCodeclimate(endpoint) { // eslint-disable-line
    return Vue.http.get(endpoint);
  }
}
