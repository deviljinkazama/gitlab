import checkmarkSvg from 'icons/_icon_checkmark.svg';
import pendingAvatarSvg from 'icons/_icon_dotted_circle.svg';
import LinkToMemberAvatar from '../../../vue_common_component/link_to_member_avatar';

export default {
  name: 'approvals-footer',
  props: {
    service: {
      type: Object,
      required: true,
    },
    approvedBy: {
      type: Array,
      required: false,
    },
    approvalsLeft: {
      type: Number,
      required: false,
    },
    userCanApprove: {
      type: Boolean,
      required: false,
    },
    userHasApproved: {
      type: Boolean,
      required: false,
    },
    suggestedApprovers: {
      type: Array,
      required: false,
    },
  },
  data() {
    return {
      unapproving: false,
      checkmarkSvg,
      pendingAvatarSvg,
    };
  },
  components: {
    'link-to-member-avatar': LinkToMemberAvatar,
  },
  computed: {
    showUnapproveButton() {
      return this.userHasApproved && !this.userCanApprove;
    },
  },
  methods: {
    unapproveMergeRequest() {
      this.unapproving = true;
      this.service.unapproveMergeRequest().then(() => {
        this.unapproving = false;
      });
    },
  },
  template: `
    <div class='mr-widget-footer approved-by-users approvals-footer clearfix mr-approvals-footer'>
      <span class='approvers-prefix'> Approved by </span>
      <span v-for='approver in approvedBy'>
        <link-to-member-avatar
          extra-link-class='approver-avatar'
          :avatar-url='approver.user.avatar_url'
          :display-name='approver.user.name'
          :profile-url='approver.user.web_url'
          :avatar-html='checkmarkSvg'
          :show-tooltip='true'>
        </link-to-member-avatar>
      </span>
      <span v-for='n in approvalsLeft'>
        <link-to-member-avatar
          :clickable='false'
          :avatar-html='pendingAvatarSvg'
          :show-tooltip='false'
          extra-link-class='hide-asset'>
        </link-to-member-avatar>
      </span>
      <span class='unapprove-btn-wrap' v-if='showUnapproveButton'>
        <button
          :disabled='unapproving'
          @click='unapproveMergeRequest'
          class='btn btn-link unapprove-btn'>
          <i class='fa fa-close'></i>
          Remove your approval
        </button>
      </span>
    </div>
  `,
};
