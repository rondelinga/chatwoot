import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/routing-types'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'routing_types_list',
          component: Index,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
