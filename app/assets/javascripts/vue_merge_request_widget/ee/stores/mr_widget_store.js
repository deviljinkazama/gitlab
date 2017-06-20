import CEMergeRequestStore from '../../stores/mr_widget_store';

const unmergedStatesEE = [
  'rebase',
];

export default class MergeRequestStore extends CEMergeRequestStore {
  constructor(data) {
    super(data);
    this.initCodeclimate(data);
  }

  setData(data) {
    this.initGeo(data);
    this.initSquashBeforeMerge(data);
    this.initRebase(data);
    this.initApprovals(data);

    super.setData(data);

    this.isMerged = this.isMerged && unmergedStatesEE.indexOf(data.state) === -1;
  }

  initSquashBeforeMerge(data) {
    this.squashBeforeMergeHelpPath = this.squashBeforeMergeHelpPath
      || data.squash_before_merge_help_path;
    this.enableSquashBeforeMerge = true;
  }

  initRebase(data) {
    this.shouldBeRebased = !!data.should_be_rebased;
    this.canPushToSourceBranch = data.can_push_to_source_branch;
    this.rebaseInProgress = data.rebase_in_progress;
    this.approvalsLeft = !data.approved;
    this.rebasePath = data.rebase_path;
    this.ffOnlyEnabled = data.ff_only_enabled;
  }

  initGeo(data) {
    this.isGeoSecondaryNode = this.isGeoSecondaryNode || data.is_geo_secondary_node;
    this.geoSecondaryHelpPath = this.geoSecondaryHelpPath || data.geo_secondary_help_path;
  }

  initApprovals(data) {
    this.isApproved = this.isApproved || false;
    this.approvals = this.approvals || null;
    this.approvalsPath = data.approvals_path || this.approvalsPath;
    this.approvalsRequired = Boolean(this.approvalsPath);
  }

  setApprovals(data) {
    this.approvals = data;
    this.approvalsLeft = !!data.approvals_left;
    this.isApproved = !this.approvalsLeft || false;
    this.preventMerge = this.approvalsRequired && this.approvalsLeft;
  }

  initCodeclimate(data) {
    this.codeclimate = data.codeclimate;
    this.codeclimateMetrics = {
      headIssues: [],
      baseIssues: [],
      newIssues: [],
      resolvedIssues: [],
    };
  }

  setCodeclimateHeadMetrics(data) {
    this.codeclimateMetrics.headIssues = data;
  }

  setCodeclimateBaseMetrics(data) {
    this.codeclimateMetrics.baseIssues = data;
  }

  compareCodeclimateMetrics() {
    const { headIssues, baseIssues } = this.codeclimateMetrics;

    this.codeclimateMetrics.newIssues = this.filterByFingerprint(headIssues, baseIssues);
    this.codeclimateMetrics.resolvedIssues = this.filterByFingerprint(baseIssues, headIssues);
  }

  filterByFingerprint(firstArray, secondArray) { // eslint-disable-line
    return firstArray.filter(item => !secondArray.find(el => el.fingerprint === item.fingerprint));
  }
}
