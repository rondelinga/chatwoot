import InboxTeamsAPI from '../../api/inboxTeams';

export const actions = {
  get(_, { inboxId }) {
    return InboxTeamsAPI.show(inboxId);
  },
  update(_, { inboxId, teamConfigs }) {
    return InboxTeamsAPI.update({ inboxId, teamConfigs });
  },
};

export default {
  namespaced: true,
  actions,
};
