import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

export const MESSAGE_EDIT_WINDOW_SECONDS = 15 * 60;
export const EDIT_MESSAGE_EVENT = 'FORK_EDIT_MESSAGE';

export const canEditOutgoingMessage = ({
  private: isPrivate,
  content,
  messageType,
  contentType,
  contentAttributes,
  createdAt,
  outgoingType,
  textContentType,
}) => {
  if (isPrivate || !content) return false;
  if (messageType !== outgoingType) return false;
  if (contentType !== textContentType) return false;
  if (contentAttributes?.deleted) return false;

  return Date.now() / 1000 - createdAt < MESSAGE_EDIT_WINDOW_SECONDS;
};

export const openMessageEdit = message => {
  // Expands a folded reply box via the existing upstream listener.
  emitter.emit(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE);
  emitter.emit(EDIT_MESSAGE_EVENT, message);
};
