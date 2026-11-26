import EditMessageApi from '../../../../api/editMessage';
import types from '../../../mutation-types';

export default {
  editMessage: async ({ commit }, { conversationId, messageId, content }) => {
    const { data } = await EditMessageApi.edit(
      conversationId,
      messageId,
      content
    );
    commit(types.ADD_MESSAGE, data);
    return data;
  },
};
