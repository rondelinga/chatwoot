export const assigneeOf = conversation => {
  const assignee = conversation?.meta?.assignee;
  if (!assignee?.id) return null;

  const assigneeType = conversation.meta?.assignee_type;
  if (!assigneeType || assigneeType === 'User') {
    return { kind: 'agent', id: assignee.id, name: assignee.name };
  }

  return {
    kind: 'bot',
    id: `${assigneeType}:${assignee.id}`,
    name: assignee.name,
    thumbnail: assignee.thumbnail,
  };
};

export const chatCounts = conversations => {
  const agents = {};
  const inboxes = {};
  const bots = {};

  conversations.forEach(conversation => {
    const inboxId = conversation.inbox_id;
    if (inboxId) inboxes[inboxId] = (inboxes[inboxId] || 0) + 1;

    const assignee = assigneeOf(conversation);
    if (!assignee) return;

    const bucket = assignee.kind === 'bot' ? bots : agents;
    bucket[assignee.id] = (bucket[assignee.id] || 0) + 1;
  });

  return { agents, inboxes, bots };
};

export const activeChatForAgent = (conversations, agentId) => {
  const id = Number(agentId);
  return conversations
    .filter(conversation => {
      const assignee = assigneeOf(conversation);
      return assignee?.kind === 'agent' && assignee.id === id;
    })
    .sort(
      (left, right) =>
        (right.last_activity_at || right.timestamp || 0) -
        (left.last_activity_at || left.timestamp || 0)
    )[0];
};

const byName = (left, right) =>
  (left.name || '').localeCompare(right.name || '');

const statusOf = agent => agent.availability_status || 'offline';

export const compareSuperviseAgents = (left, right, counts, typingIds) => {
  const rank = { online: 0, busy: 1, offline: 2 };
  const leftStatus = statusOf(left);
  const rightStatus = statusOf(right);
  if (rank[leftStatus] !== rank[rightStatus]) {
    return rank[leftStatus] - rank[rightStatus];
  }

  if (leftStatus === 'offline') return byName(left, right);

  if (leftStatus === 'online') {
    const leftTyping = typingIds.has(left.id) ? 1 : 0;
    const rightTyping = typingIds.has(right.id) ? 1 : 0;
    if (leftTyping !== rightTyping) return rightTyping - leftTyping;
  }

  const leftCount = counts[left.id] || 0;
  const rightCount = counts[right.id] || 0;
  if (leftCount !== rightCount) return rightCount - leftCount;
  return byName(left, right);
};

export const compareInboxAgents = (left, right, counts) => {
  const rankOf = agent => {
    const status = statusOf(agent);
    const count = counts[agent.id] || 0;
    if (status === 'online' && count > 0) return 0;
    if (status === 'online') return 1;
    if (status === 'busy') return 2;
    return 3;
  };

  const leftRank = rankOf(left);
  const rightRank = rankOf(right);
  if (leftRank !== rightRank) return leftRank - rightRank;
  if (leftRank === 0) {
    const leftCount = counts[left.id] || 0;
    const rightCount = counts[right.id] || 0;
    if (leftCount !== rightCount) return rightCount - leftCount;
  }
  return byName(left, right);
};
