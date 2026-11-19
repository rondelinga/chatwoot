import { MESSAGE_TYPE } from 'shared/constants/messages';
import { showBadgeOnFavicon, initFaviconSwitcher } from './faviconHelper';

import { EVENT_TYPES } from 'dashboard/routes/dashboard/settings/profile/constants.js';
import GlobalStore from 'dashboard/store';
import AudioNotificationStore from './AudioNotificationStore';
import { AudioNotificationService } from './AudioNotificationService';
import { isConversationMuted } from 'dashboard/composables/useMutedConversations';
import {
  isConversationAssignedToMe,
  isConversationUnassigned,
  isMessageFromCurrentUser,
} from './AudioMessageHelper';
import WindowVisibilityHelper from './WindowVisibilityHelper';

const NOTIFICATION_TIME = 30000;
const DEFAULT_ALERT_TYPE = ['none'];

const conversationAssigneeId = conversation =>
  conversation?.meta?.assignee?.id ?? conversation?.assignee_id;

export class DashboardAudioNotificationHelper {
  constructor(store) {
    if (!store) {
      throw new Error('store is required');
    }
    this.store = new AudioNotificationStore(store);
    this.audioService = new AudioNotificationService(() =>
      this.store.getSoundSettings()
    );

    this.notificationConfig = {
      audioAlertType: DEFAULT_ALERT_TYPE,
      playAlertOnlyWhenHidden: true,
      alertIfUnreadConversationExist: false,
    };

    this.recurringNotificationTimer = null;
    this.currentUser = null;
  }

  playAudioAlert = message => {
    this.audioService.playNewMessage(message?.conversation_id);
  };

  onAssigneeChanged = conversation => {
    if (!this.currentUser) return;

    const assigneeId = conversationAssigneeId(conversation);
    if (!assigneeId || assigneeId !== this.currentUser.id) return;

    if (!this.shouldPlayAlert()) return;

    this.audioService.playNewConversation();
    showBadgeOnFavicon();
    this.playAudioEvery30Seconds();
  };

  onConversationCreated = conversation => {
    if (!this.currentUser) return;
    if (!this.store.hasConversationPermission(this.currentUser)) return;
    if (!this.shouldNotifyOnConversation(conversation)) return;
    if (!this.shouldPlayAlert()) return;

    this.audioService.playNewConversation();
    showBadgeOnFavicon();
    this.playAudioEvery30Seconds();
  };

  set = ({
    currentUser,
    alwaysPlayAudioAlert,
    alertIfUnreadConversationExist,
    audioAlertType = DEFAULT_ALERT_TYPE,
  }) => {
    this.notificationConfig = {
      ...this.notificationConfig,
      audioAlertType: audioAlertType.split('+').filter(Boolean),
      playAlertOnlyWhenHidden: !alwaysPlayAudioAlert,
      alertIfUnreadConversationExist: alertIfUnreadConversationExist,
    };

    this.currentUser = currentUser;

    initFaviconSwitcher();
    this.clearRecurringTimer();
    this.playAudioEvery30Seconds();
  };

  shouldPlayAlert = () => {
    if (this.notificationConfig.playAlertOnlyWhenHidden) {
      return !WindowVisibilityHelper.isWindowVisible();
    }
    return true;
  };

  executeRecurringNotification = () => {
    const conversationId =
      this.store.firstUnreadUnmutedConversationId(isConversationMuted);
    if (conversationId && this.shouldPlayAlert()) {
      this.audioService.playNewMessage(conversationId);
      showBadgeOnFavicon();
    }
    this.resetRecurringTimer();
  };

  clearRecurringTimer = () => {
    if (this.recurringNotificationTimer) {
      clearTimeout(this.recurringNotificationTimer);
    }
  };

  resetRecurringTimer = () => {
    this.clearRecurringTimer();
    this.recurringNotificationTimer = setTimeout(
      this.executeRecurringNotification,
      NOTIFICATION_TIME
    );
  };

  playAudioEvery30Seconds = () => {
    const { audioAlertType, alertIfUnreadConversationExist } =
      this.notificationConfig;

    //  Audio alert is disabled dismiss the timer
    if (audioAlertType.includes('none')) return;

    // If unread conversation flag is disabled, dismiss the timer
    if (!alertIfUnreadConversationExist) return;

    this.resetRecurringTimer();
  };

  matchesAlertEvents = ({ assignedToMe, isUnassigned }) => {
    const { audioAlertType } = this.notificationConfig;
    if (audioAlertType.includes('none')) return false;
    if (audioAlertType.includes('all')) return true;

    const shouldPlayAudio = [];

    if (
      audioAlertType.includes(EVENT_TYPES.ASSIGNED) ||
      audioAlertType.includes('mine')
    ) {
      shouldPlayAudio.push(assignedToMe);
    }
    if (audioAlertType.includes(EVENT_TYPES.UNASSIGNED)) {
      shouldPlayAudio.push(isUnassigned);
    }
    if (audioAlertType.includes(EVENT_TYPES.NOTME)) {
      shouldPlayAudio.push(!isUnassigned && !assignedToMe);
    }

    return shouldPlayAudio.some(Boolean);
  };

  triggerAlert = message => {
    if (!this.store.hasConversationPermission(this.currentUser)) return;
    if (!this.shouldNotifyOnMessage(message)) return;
    if (WindowVisibilityHelper.isWindowVisible()) {
      if (this.store.isMessageFromCurrentConversation(message)) return;
      if (this.notificationConfig.playAlertOnlyWhenHidden) return;
    }

    this.playAudioAlert(message);
    showBadgeOnFavicon();
    this.playAudioEvery30Seconds();
  };

  shouldNotifyOnConversation = conversation => {
    const assigneeId = conversationAssigneeId(conversation);
    return this.matchesAlertEvents({
      assignedToMe: assigneeId === this.currentUser.id,
      isUnassigned: !assigneeId,
    });
  };

  shouldNotifyOnMessage = message => {
    return this.matchesAlertEvents({
      assignedToMe: isConversationAssignedToMe(message, this.currentUser.id),
      isUnassigned: isConversationUnassigned(message),
    });
  };

  onConversationBotHandoff = conversation => {
    // Adapt the handoff once to the existing audio-filter contract. Bot IDs
    // must not be treated as human assignees, even when their IDs overlap.
    this.triggerAlert({
      conversation_id: conversation.id,
      conversation: {
        assignee_id:
          conversation.meta?.assignee_type === 'User'
            ? conversation.meta.assignee?.id
            : null,
      },
    });
  };

  onNewMessage = message => {
    // Captain notes are context, not requests for attention. Only the dedicated
    // handoff event alerts agents, regardless of when its explanatory note arrives.
    if (message.private && message.sender?.type === 'captain_assistant') return;

    // If the conversation status is pending, then dismiss the alert
    // This case is common for all audio event types
    if (this.store.isMessageFromPendingConversation(message)) {
      return;
    }

    // If the message is sent by the current user then dismiss the alert
    if (isMessageFromCurrentUser(message, this.currentUser.id)) {
      return;
    }

    // If the message type is not incoming or private, then dismiss the alert
    const { message_type: messageType, private: isPrivate } = message;
    if (messageType !== MESSAGE_TYPE.INCOMING && !isPrivate) {
      return;
    }

    this.triggerAlert(message);
  };
}

export default new DashboardAudioNotificationHelper(GlobalStore);
