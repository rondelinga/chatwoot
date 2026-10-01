import BaseActionCableConnector from '../../shared/helpers/BaseActionCableConnector';
import { playNewMessageNotificationInWidget } from 'widget/helpers/WidgetAudioNotificationHelper';
import { ON_AGENT_MESSAGE_RECEIVED } from '../constants/widgetBusEvents';
import { IFrameHelper } from 'widget/helpers/utils';
import { shouldTriggerMessageUpdateEvent } from './IframeEventHelper';
import { CHATWOOT_ON_MESSAGE } from '../constants/sdkEvents';
import { MESSAGE_TYPE } from './constants';
import { emitter } from '../../shared/helpers/mitt';

const sameConversationId = (left, right) =>
  left !== null &&
  left !== undefined &&
  right !== null &&
  right !== undefined &&
  Number(left) === Number(right);

const isMessageInActiveConversation = (getters, message) => {
  const { conversation_id: conversationId } = message;
  const activeConversationId =
    getters['conversationAttributes/getConversationParams'].id;
  return (
    Boolean(activeConversationId) &&
    !sameConversationId(activeConversationId, conversationId)
  );
};

const isOutgoingAgentMessage = message =>
  Number(message.message_type) === MESSAGE_TYPE.OUTGOING &&
  message.sender_type === 'User';

const WIDGET_PRESENCE_INTERVAL = 60000;

class ActionCableConnector extends BaseActionCableConnector {
  constructor(app, pubsubToken) {
    super(app, pubsubToken, '', WIDGET_PRESENCE_INTERVAL);
    this.events = {
      'message.created': this.onMessageCreated,
      'message.updated': this.onMessageUpdated,
      'conversation.typing_on': this.onTypingOn,
      'conversation.typing_off': this.onTypingOff,
      'conversation.status_changed': this.onStatusChange,
      'conversation.created': this.onConversationCreated,
      'presence.update': this.onPresenceUpdate,
      'contact.merged': this.onContactMerge,
    };
  }

  onDisconnected = () => {
    this.setLastMessageId();
  };

  onReconnect = () => {
    this.syncLatestMessages();
    // Re-fetch conversation attributes so a status change (e.g. auto-resolve)
    // that happened while disconnected is reflected, keeping the reply box state correct.
    this.app.$store.dispatch('conversationAttributes/getAttributes');
  };

  setLastMessageId = () => {
    this.app.$store.dispatch('conversation/setLastMessageId');
  };

  syncLatestMessages = () => {
    this.app.$store.dispatch('conversation/syncLatestMessages');
  };

  onStatusChange = data => {
    if (data.status === 'resolved') {
      this.app.$store.dispatch('campaign/resetCampaign');
    }
    this.app.$store.dispatch('conversationAttributes/update', data);
  };

  onMessageCreated = data => {
    if (isMessageInActiveConversation(this.app.$store.getters, data)) {
      if (isOutgoingAgentMessage(data)) {
        this.maybeShowOutboundNotification(data);
        this.refreshConversationFromOutbound();
      }
      return;
    }

    this.app.$store
      .dispatch('conversation/addOrUpdateMessage', data)
      .then(() => {
        this.maybeShowOutboundNotification(data);
        emitter.emit(ON_AGENT_MESSAGE_RECEIVED);
      });

    IFrameHelper.sendMessage({
      event: 'onEvent',
      eventIdentifier: CHATWOOT_ON_MESSAGE,
      data,
    });
    if (data.sender_type === 'User') {
      playNewMessageNotificationInWidget();
    }
  };

  onMessageUpdated = data => {
    if (isMessageInActiveConversation(this.app.$store.getters, data)) {
      return;
    }

    if (shouldTriggerMessageUpdateEvent(data)) {
      IFrameHelper.sendMessage({
        event: 'onEvent',
        eventIdentifier: CHATWOOT_ON_MESSAGE,
        data,
      });
    }

    this.app.$store.dispatch('conversation/addOrUpdateMessage', data);
  };

  onConversationCreated = async data => {
    if (data?.id) {
      this.app.$store.dispatch('conversationAttributes/setFromEvent', data);
    }
    this.maybeShowOutboundNotification({
      sender_type: 'User',
      message_type: 1,
    });
    await this.refreshConversationFromOutbound();
  };

  refreshConversationFromOutbound = async () => {
    await this.app.$store.dispatch('conversation/clearConversations');
    await this.app.$store.dispatch('conversationAttributes/getAttributes');
    await this.app.$store.dispatch('conversation/fetchOldConversations');
    emitter.emit(ON_AGENT_MESSAGE_RECEIVED);
  };

  maybeShowOutboundNotification = data => {
    if (!isOutgoingAgentMessage(data)) return;

    const isWidgetOpen = this.app.$store.getters['appConfig/getIsWidgetOpen'];
    if (isWidgetOpen) return;

    this.app.$store.dispatch('conversation/setShowOutboundNotification', true);
  };

  onPresenceUpdate = data => {
    this.app.$store.dispatch('agent/updatePresence', data.users);
  };

  // eslint-disable-next-line class-methods-use-this
  onContactMerge = data => {
    const { pubsub_token: pubsubToken } = data;
    ActionCableConnector.refreshConnector(pubsubToken);
  };

  onTypingOn = data => {
    const activeConversationId =
      this.app.$store.getters['conversationAttributes/getConversationParams']
        .id;
    const isUserTypingOnAnotherConversation =
      data.conversation && data.conversation.id !== activeConversationId;

    if (isUserTypingOnAnotherConversation || data.is_private) {
      return;
    }
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'on',
    });
    this.initTimer();
  };

  onTypingOff = () => {
    this.clearTimer();
    this.app.$store.dispatch('conversation/toggleAgentTyping', {
      status: 'off',
    });
  };

  clearTimer = () => {
    if (this.CancelTyping) {
      clearTimeout(this.CancelTyping);
      this.CancelTyping = null;
    }
  };

  initTimer = () => {
    // Turn off typing automatically after 30 seconds
    this.CancelTyping = setTimeout(() => {
      this.onTypingOff();
    }, 30000);
  };
}

export default ActionCableConnector;
