<script>
import GfmAutoComplete from '~/gfm_auto_complete';
import eventHub from '../event_hub';
import IssueToken from './issue_token.vue';

export default {
  name: 'AddIssuableForm',

  props: {
    inputValue: {
      type: String,
      required: true,
    },
    addButtonLabel: {
      type: String,
      required: true,
    },
    pendingReferences: {
      type: Array,
      required: false,
      default: () => [],
    },
    autoCompleteSources: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isSubmitting: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data() {
    return {
      isInputFocused: false,
      isAutoCompleteOpen: false,
    };
  },

  components: {
    issueToken: IssueToken,
  },

  computed: {
    isSubmitButtonDisabled() {
      return this.pendingReferences.length === 0 || this.isSubmitting;
    },
  },

  methods: {
    onInput() {
      const value = this.$refs.input.value;
      eventHub.$emit('addIssuableFormInput', value, $(this.$refs.input).caret('pos'));
    },
    onFocus() {
      this.isInputFocused = true;
    },
    onBlur() {
      this.isInputFocused = false;

      // Avoid tokenizing partial input when clicking an autocomplete item
      if (!this.isAutoCompleteOpen) {
        const value = this.$refs.input.value;
        eventHub.$emit('addIssuableFormBlur', value);
      }
    },
    onAutoCompleteToggled(isOpen) {
      this.isAutoCompleteOpen = isOpen;
    },
    onInputWrapperClick() {
      this.$refs.input.focus();
    },
    onFormSubmit() {
      eventHub.$emit('addIssuableFormSubmit');
    },
    onFormCancel() {
      eventHub.$emit('addIssuableFormCancel');
    },
  },

  mounted() {
    const $input = $(this.$refs.input);
    new GfmAutoComplete(this.autoCompleteSources).setup($input, {
      issues: true,
    });
    $input.on('shown-issues.atwho', this.onAutoCompleteToggled.bind(this, true));
    $input.on('hidden-issues.atwho', this.onAutoCompleteToggled.bind(this, false));
    $input.on('inserted-issues.atwho', this.onInput);
  },

  beforeDestroy() {
    const $input = $(this.$refs.input);
    $input.off('shown-issues.atwho');
    $input.off('hidden-issues.atwho');
    $input.off('inserted-issues.atwho', this.onInput);
  },
};
</script>

<template>
  <div>
    <div
      ref="issuableFormWrapper"
      class="add-issuable-form-input-wrapper form-control"
      :class="{ focus: isInputFocused }"
      role="button"
      @click="onInputWrapperClick">
      <ul class="add-issuable-form-input-token-list">
        <li
          :key="reference"
          v-for="(reference, index) in pendingReferences"
          class="js-add-issuable-form-token-list-item add-issuable-form-token-list-item">
          <issue-token
            event-namespace="pendingIssuable"
            :id-key="index"
            :display-reference="reference"
            :can-remove="true" />
        </li>
        <li class="add-issuable-form-input-list-item">
          <input
            ref="input"
            type="text"
            class="js-add-issuable-form-input add-issuable-form-input"
            :value="inputValue"
            placeholder="Search issues..."
            @input="onInput"
            @focus="onFocus"
            @blur="onBlur" />
        </li>
      </ul>
    </div>
    <div class="add-issuable-form-actions clearfix">
      <button
        ref="addButton"
        type="button"
        class="js-add-issuable-form-add-button btn btn-new pull-left"
        @click="onFormSubmit"
        :disabled="isSubmitButtonDisabled">
        {{ addButtonLabel }}
      </button>
      <button
        type="button"
        class="btn btn-default pull-right"
        @click="onFormCancel">
        Cancel
      </button>
    </div>
  </div>
</template>
