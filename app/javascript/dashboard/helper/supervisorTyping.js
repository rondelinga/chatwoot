import { createConsumer } from '@rails/actioncable';

const THROTTLE_MS = 400;

export const editorPlainText = value =>
  String(value || '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();

export function createSupervisorTypingChannel({
  accountId,
  userId,
  pubsubToken,
  onReceived = () => {},
}) {
  const { websocketURL = '' } = window.chatwootConfig || {};
  const consumer = createConsumer(websocketURL || undefined);
  let subscription = null;
  let conversationId = null;
  let pendingText = '';
  let lastSentAt = 0;
  let timer = null;

  const unsubscribe = () => {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    conversationId = null;
  };

  const subscribe = id => {
    const nextId = Number(id);
    if (!nextId || conversationId === nextId) return;

    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }

    conversationId = nextId;
    subscription = consumer.subscriptions.create(
      {
        channel: 'ConversationChannel',
        id: nextId,
        account_id: accountId,
        user_id: userId,
        pubsub_token: pubsubToken,
      },
      { received: onReceived }
    );
  };

  const flush = () => {
    timer = null;
    lastSentAt = Date.now();
    if (!subscription) return;
    subscription.perform('supervisor_typing', { text: pendingText });
  };

  const send = text => {
    pendingText = text;
    const elapsed = Date.now() - lastSentAt;
    if (elapsed >= THROTTLE_MS) {
      if (timer) {
        clearTimeout(timer);
        timer = null;
      }
      flush();
      return;
    }
    if (!timer) {
      timer = setTimeout(flush, THROTTLE_MS - elapsed);
    }
  };

  const disconnect = () => {
    unsubscribe();
    consumer.disconnect();
  };

  return { subscribe, send, unsubscribe, disconnect };
}
