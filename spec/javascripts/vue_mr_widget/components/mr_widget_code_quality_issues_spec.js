import Vue from 'vue';
import mrWidgetCodeQualityIssues from '~/vue_merge_request_widget/ee/components/mr_widget_code_quality_issues.vue';

describe('Merge Request Code Quality Issues', () => {
  let vm;
  let MRWidgetCodeQualityIssues;
  let mountComponent;

  beforeEach(() => {
    MRWidgetCodeQualityIssues = Vue.extend(mrWidgetCodeQualityIssues);
    mountComponent = props => new MRWidgetCodeQualityIssues({ propsData: props }).$mount();
  });

  describe('Renders provided list of issues', () => {
    describe('with positions and lines', () => {
      beforeEach(() => {
        vm = mountComponent({
          type: 'success',
          issues: [{
            check_name: 'foo',
            location: {
              path: 'bar',
              positions: '81',
              lines: '21',
            },
          }],
        });
      });

      it('should render issue', () => {
        expect(
          vm.$el.querySelector('li span').textContent.trim().replace(/\s+/g, ''),
        ).toEqual('Fixed:foobar8121');
      });
    });

    describe('without positions and lines', () => {
      beforeEach(() => {
        vm = mountComponent({
          type: 'success',
          issues: [{
            check_name: 'foo',
            location: {
              path: 'bar',
            },
          }],
        });
      });

      it('should render issue without position and lines', () => {
        expect(
          vm.$el.querySelector('li span').textContent.trim().replace(/\s+/g, ''),
        ).toEqual('Fixed:foobar');
      });
    });

    describe('for type failed', () => {
      beforeEach(() => {
        vm = mountComponent({
          type: 'failed',
          issues: [{
            check_name: 'foo',
            location: {
              path: 'bar',
              positions: '81',
              lines: '21',
            },
          }],
        });
      });

      it('should render failed minus icon', () => {
        expect(vm.$el.querySelector('li').classList.contains('failed')).toEqual(true);
        expect(vm.$el.querySelector('li i').classList.contains('fa-minus')).toEqual(true);
      });
    });

    describe('for type success', () => {
      beforeEach(() => {
        vm = mountComponent({
          type: 'success',
          issues: [{
            check_name: 'foo',
            location: {
              path: 'bar',
              positions: '81',
              lines: '21',
            },
          }],
        });
      });

      it('should render success plus icon', () => {
        expect(vm.$el.querySelector('li').classList.contains('success')).toEqual(true);
        expect(vm.$el.querySelector('li i').classList.contains('fa-plus')).toEqual(true);
      });
    });
  });
});
