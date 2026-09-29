const getOverviewAgentSortGroup = (status, openCount) => {
  if (status === 'online' && openCount > 0) return 1;
  if (status === 'online') return 2;
  if (status === 'busy') return 3;
  return 4;
};

export const compareOverviewAgents = (a, b) => {
  const groupA = getOverviewAgentSortGroup(a.status, a.open);
  const groupB = getOverviewAgentSortGroup(b.status, b.open);

  if (groupA !== groupB) return groupA - groupB;

  if (groupA === 1) {
    const openDiff = a.open - b.open;
    if (openDiff !== 0) return openDiff;
  }

  return a.agent.localeCompare(b.agent);
};
