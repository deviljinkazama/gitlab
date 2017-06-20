import MergeRequestStore from '~/vue_merge_request_widget/ee/stores/mr_widget_store';
import mockData from '../../mock_data';

describe('MergeRequestStore', () => {
  let store;

  beforeEach(() => {
    store = new MergeRequestStore(mockData);
  });

  describe('setData', () => {
    it('sets isMerged to false for rebase state', () => {
      store.setData({ ...mockData, state: 'rebase' });

      expect(store.isMerged).toBe(false);
    });

    it('sets isMerged to true for merged state', () => {
      store.setData({ ...mockData, state: 'merged' });

      expect(store.isMerged).toBe(true);
    });
  });
});
