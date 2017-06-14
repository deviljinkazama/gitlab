<script>
import ciIconBadge from './ci_badge_link.vue';
<<<<<<< HEAD
import timeagoTooltip from './time_ago_tooltip.vue';
import tooltipMixin from '../mixins/tooltip';
import userAvatarLink from './user_avatar/user_avatar_link.vue';
=======
import loadingIcon from './loading_icon.vue';
import timeagoTooltip from './time_ago_tooltip.vue';
import tooltipMixin from '../mixins/tooltip';
import userAvatarImage from './user_avatar/user_avatar_image.vue';
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

/**
 * Renders header component for job and pipeline page based on UI mockups
 *
 * Used in:
 * - job show page
 * - pipeline show page
 */
export default {
  props: {
    status: {
      type: Object,
      required: true,
    },
    itemName: {
      type: String,
      required: true,
    },
    itemId: {
      type: Number,
      required: true,
    },
    time: {
      type: String,
      required: true,
    },
    user: {
      type: Object,
<<<<<<< HEAD
      required: true,
=======
      required: false,
      default: () => ({}),
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    },
    actions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },

  mixins: [
    tooltipMixin,
  ],

  components: {
    ciIconBadge,
<<<<<<< HEAD
    timeagoTooltip,
    userAvatarLink,
=======
    loadingIcon,
    timeagoTooltip,
    userAvatarImage,
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  },

  computed: {
    userAvatarAltText() {
      return `${this.user.name}'s avatar`;
    },
  },

  methods: {
    onClickAction(action) {
<<<<<<< HEAD
      this.$emit('postAction', action);
=======
      this.$emit('actionClicked', action);
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    },
  },
};
</script>
<template>
<<<<<<< HEAD
  <header class="page-content-header top-area">
=======
  <header class="page-content-header">
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    <section class="header-main-content">

      <ci-icon-badge :status="status" />

      <strong>
        {{itemName}} #{{itemId}}
      </strong>

      triggered

      <timeago-tooltip :time="time" />

      by

<<<<<<< HEAD
      <user-avatar-link
        :link-href="user.web_url"
        :img-src="user.avatar_url"
        :img-alt="userAvatarAltText"
        :tooltip-text="user.name"
        :img-size="24"
        />

      <a
        :href="user.web_url"
        :title="user.email"
        class="js-user-link commit-committer-link"
        ref="tooltip">
        {{user.name}}
      </a>
=======
      <template v-if="user">
        <a
          :href="user.path"
          :title="user.email"
          class="js-user-link commit-committer-link"
          ref="tooltip">

          <user-avatar-image
            :img-src="user.avatar_url"
            :img-alt="userAvatarAltText"
            :tooltip-text="user.name"
            :img-size="24"
            />

          {{user.name}}
        </a>
      </template>
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    </section>

    <section
      class="header-action-button nav-controls"
      v-if="actions.length">
      <template
        v-for="action in actions">
        <a
          v-if="action.type === 'link'"
          :href="action.path"
          :class="action.cssClass">
          {{action.label}}
        </a>

        <button
          v-else="action.type === 'button'"
          @click="onClickAction(action)"
<<<<<<< HEAD
          :class="action.cssClass"
          type="button">
          {{action.label}}
        </button>

=======
          :disabled="action.isLoading"
          :class="action.cssClass"
          type="button">
          {{action.label}}

          <i
            v-show="action.isLoading"
            class="fa fa-spin fa-spinner"
            aria-hidden="true">
          </i>
        </button>
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
      </template>
    </section>
  </header>
</template>
