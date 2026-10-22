import { frontendURL } from 'dashboard/helper/URLHelper';
import SuperviseIndex from './supervise/Index.vue';
import InboxIndex from './inbox/Index.vue';

const meta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL(
      'accounts/:accountId/supervision/supervise/:agentId/conversations/:conversationId'
    ),
    name: 'supervision_supervise_conversation',
    component: SuperviseIndex,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/supervision/supervise/:agentId?'),
    name: 'supervision_supervise',
    component: SuperviseIndex,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/supervision/inbox'),
    name: 'supervision_inbox',
    component: InboxIndex,
    meta,
  },
];
