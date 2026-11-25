import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { EDIT_MESSAGE_EVENT } from 'dashboard/helper/messageEdit';
import { emitter } from 'shared/helpers/mitt';

export default {
  data() {
    return {
      editingMessage: null,
      draftBeforeEdit: null,
      isSavingEdit: false,
    };
  },
  computed: {
    isEditingMessage() {
      return Boolean(this.editingMessage);
    },
    editSaveButtonLabel() {
      const keyLabel = this.isEditorHotKeyEnabled?.('cmd_enter')
        ? `(${this.shortcutKey})`
        : '(↵)';
      return `${this.$t('EDIT_MESSAGE.SAVE')} ${keyLabel}`;
    },
  },
  mounted() {
    emitter.on(EDIT_MESSAGE_EVENT, this.startEditing);
  },
  unmounted() {
    emitter.off(EDIT_MESSAGE_EVENT, this.startEditing);
  },
  methods: {
    startEditing(message) {
      if (!message?.id) return;

      if (!this.editingMessage) {
        this.draftBeforeEdit = this.message;
      }
      this.editingMessage = message;
      this.message = message.originalContent || message.content || '';
      this.$nextTick(() => this.messageEditor?.focusEditorInputField('end'));
    },
    finishEditing() {
      const draft = this.draftBeforeEdit ?? '';
      this.editingMessage = null;
      this.draftBeforeEdit = null;
      this.message = draft;
      this.$nextTick(() => this.messageEditor?.focusEditorInputField());
    },
    async saveEditedMessage() {
      if (!this.editingMessage || this.isSavingEdit) return;

      this.isSavingEdit = true;
      try {
        await this.$store.dispatch('editMessage', {
          conversationId:
            this.editingMessage.conversation_id || this.conversationId,
          messageId: this.editingMessage.id,
          content: this.message,
        });
        useAlert(this.$t('EDIT_MESSAGE.SUCCESS'));
        this.finishEditing();
      } catch (error) {
        const apiError = parseAPIErrorResponse(error);
        useAlert(
          typeof apiError === 'string'
            ? apiError
            : this.$t('EDIT_MESSAGE.ERROR')
        );
      } finally {
        this.isSavingEdit = false;
      }
    },
    interceptSendWhileEditing() {
      if (!this.editingMessage) return false;
      this.saveEditedMessage();
      return true;
    },
    clearEditingBeforeDraftSwitch() {
      if (!this.editingMessage) return;
      this.message = this.draftBeforeEdit ?? '';
      this.editingMessage = null;
      this.draftBeforeEdit = null;
    },
  },
};
