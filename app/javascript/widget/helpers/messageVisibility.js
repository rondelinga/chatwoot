import { MESSAGE_TYPE } from './constants';

// Mirrors MessageFinder#messages when filter_internal_messages is true.
export const isInternalWidgetMessage = message => {
  if (!message) return true;

  if (message.private) return true;

  return Number(message.message_type) === MESSAGE_TYPE.ACTIVITY;
};
