import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';
import wootConstants from 'dashboard/constants/globals';

class AudioNotificationStore {
  constructor(store) {
    this.store = store;
  }

  hasUnreadConversation = () => {
    const mineConversation = this.store.getters.getMineChats({
      assigneeType: 'me',
      status: 'open',
    });

    return mineConversation.some(conv => conv.unread_count > 0);
  };

  firstUnreadUnmutedConversationId = isMuted => {
    const mineConversation = this.store.getters.getMineChats({
      assigneeType: 'me',
      status: 'open',
    });

    const conversation = mineConversation.find(
      conv => conv.unread_count > 0 && !isMuted(conv.id)
    );
    return conversation?.id;
  };

  getSoundSettings = () => {
    return this.store.getters['userNotificationSettings/getSoundSettings'];
  };

  isMessageFromPendingConversation = (message = {}) => {
    const { conversation_id: conversationId } = message || {};
    if (!conversationId) return false;

    const activeConversation =
      this.store.getters.getConversationById(conversationId);
    return activeConversation?.status === wootConstants.STATUS_TYPE.PENDING;
  };

  isMessageFromCurrentConversation = message => {
    return this.store.getters.getSelectedChat?.id === message.conversation_id;
  };

  hasConversationPermission = user => {
    const currentAccountId = this.store.getters.getCurrentAccountId;
    // Get the user permissions for the current account
    const userPermissions = getUserPermissions(user, currentAccountId);
    // Check if the user has the required permissions
    const hasRequiredPermission = [...ROLES, ...CONVERSATION_PERMISSIONS].some(
      permission => userPermissions.includes(permission)
    );
    return hasRequiredPermission;
  };
}

export default AudioNotificationStore;
