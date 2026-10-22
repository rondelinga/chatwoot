import { computed, h } from 'vue';
import { useI18n } from 'vue-i18n';
import { useOperators } from './operators';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useChannelIcon } from 'next/icon/provider';
import { createContactSearcher } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';
import EmojiIcon from 'dashboard/components-next/emoji-icon-picker/EmojiIcon.vue';
import {
  buildAttributesFilterTypes,
  CONVERSATION_ATTRIBUTES,
} from './helper/filterHelper';
import { groupFilterTypes } from './helper/filterAttributeIcons';
import { UNASSIGNED_ID } from 'dashboard/constants/filters.js';

/**
 * @typedef {Object} FilterOption
 * @property {string|number} id
 * @property {string} name
 * @property {import('vue').VNode} [icon]
 */

/**
 * @typedef {Object} FilterOperator
 * @property {string} value
 * @property {string} label
 * @property {string} icon
 * @property {boolean} hasInput
 */

/**
 * @typedef {Object} FilterType
 * @property {string} attributeKey - The attribute key
 * @property {string} value - This is a proxy for the attribute key used in FilterSelect
 * @property {string} attributeName - The attribute name used to display on the UI
 * @property {string} label - This is a proxy for the attribute name used in FilterSelect
 * @property {'multiSelect'|'searchSelect'|'asyncSearchSelect'|'plainText'|'date'|'booleanSelect'} inputType - The input type for the attribute
 * @property {FilterOption[]} [options] - The options available for the attribute if it is a multiSelect or singleSelect type
 * @property {'text'|'number'} dataType
 * @property {FilterOperator[]} filterOperators - The operators available for the attribute
 * @property {'standard'|'additional'|'customAttributes'} attributeModel
 */

/**
 * @typedef {Object} FilterGroup
 * @property {string} name
 * @property {FilterType[]} attributes
 */

/**
 * Composable that provides conversation filtering context
 * @returns {{ filterTypes: import('vue').ComputedRef<FilterType[]>, filterGroups: import('vue').ComputedRef<FilterGroup[]> }}
 */
export function useConversationFilterContext() {
  const { t } = useI18n();

  const conversationAttributes = useMapGetter(
    'attributes/getConversationAttributes'
  );

  const labels = useMapGetter('labels/getLabels');
  const agents = useMapGetter('agents/getAgents');
  const inboxes = useMapGetter('inboxes/getInboxes');
  const teams = useMapGetter('teams/getTeams');

  const {
    equalityOperators,
    presenceOperators,
    labelOperators,
    containmentOperators,
    dateOperators,
    operators,
    getOperatorTypes,
  } = useOperators();

  const searchContacts = createContactSearcher();

  const contactOptionName = contact =>
    contact.name ||
    contact.email ||
    contact.phoneNumber ||
    contact.identifier ||
    t('FILTER.CONTACT_FALLBACK', { id: contact.id });

  const searchContactOptions = async query => {
    const contacts = await searchContacts(query, {
      skipMinLength: true,
      reachableOnly: false,
    });

    // null means the request was aborted (a newer search is in-flight)
    if (contacts === null) return null;

    return contacts.map(contact => ({
      id: contact.id,
      name: contactOptionName(contact),
    }));
  };

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const customFilterTypes = computed(() =>
    buildAttributesFilterTypes(
      conversationAttributes.value,
      getOperatorTypes,
      'conversation'
    )
  );

  /**
   * @type {import('vue').ComputedRef<FilterType[]>}
   */
  const filterTypes = computed(() => [
    {
      attributeKey: CONVERSATION_ATTRIBUTES.STATUS,
      value: CONVERSATION_ATTRIBUTES.STATUS,
      attributeName: t('FILTER.ATTRIBUTES.STATUS'),
      label: t('FILTER.ATTRIBUTES.STATUS'),
      inputType: 'multiSelect',
      options: [
        'open',
        'resolved',
        'pending',
        'queued',
        'proxied',
        'snoozed',
        'all',
      ].map(id => {
        return {
          id,
          name: t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${id}.TEXT`),
        };
      }),
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.PRIORITY,
      value: CONVERSATION_ATTRIBUTES.PRIORITY,
      attributeName: t('FILTER.ATTRIBUTES.PRIORITY'),
      label: t('FILTER.ATTRIBUTES.PRIORITY'),
      inputType: 'multiSelect',
      options: ['low', 'medium', 'high', 'urgent'].map(id => {
        return {
          id,
          name: t(`CONVERSATION.PRIORITY.OPTIONS.${id.toUpperCase()}`),
        };
      }),
      dataType: 'text',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.ASSIGNEE_ID,
      value: CONVERSATION_ATTRIBUTES.ASSIGNEE_ID,
      attributeName: t('FILTER.ATTRIBUTES.ASSIGNEE_NAME'),
      label: t('FILTER.ATTRIBUTES.ASSIGNEE_NAME'),
      inputType: 'multiSelect',
      alwaysShowSearch: true,
      options: [
        {
          id: UNASSIGNED_ID,
          name: t('FILTER.UNASSIGNED'),
          icon: 'i-lucide-user-x',
        },
        ...agents.value.map(agent => ({
          id: agent.id,
          name: agent.name,
          thumbnail: agent.thumbnail ?? '',
        })),
      ],
      dataType: 'text',
      filterOperators: presenceOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.INBOX_ID,
      value: CONVERSATION_ATTRIBUTES.INBOX_ID,
      attributeName: t('FILTER.ATTRIBUTES.INBOX_NAME'),
      label: t('FILTER.ATTRIBUTES.INBOX_NAME'),
      inputType: 'multiSelect',
      alwaysShowSearch: true,
      options: inboxes.value.map(inbox => {
        return {
          ...inbox,
          icon: useChannelIcon(inbox).value,
        };
      }),
      dataType: 'text',
      filterOperators: presenceOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.TEAM_ID,
      value: CONVERSATION_ATTRIBUTES.TEAM_ID,
      attributeName: t('FILTER.ATTRIBUTES.TEAM_NAME'),
      label: t('FILTER.ATTRIBUTES.TEAM_NAME'),
      inputType: 'searchSelect',
      options: teams.value.map(team => ({
        id: team.id,
        name: team.name,
        icon: team.icon
          ? h(EmojiIcon, {
              value: team.icon,
              color: team.icon_color,
              class: 'size-4',
            })
          : undefined,
      })),
      dataType: 'number',
      filterOperators: presenceOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.CONTACT_ID,
      value: CONVERSATION_ATTRIBUTES.CONTACT_ID,
      attributeName: t('FILTER.ATTRIBUTES.CONTACT'),
      label: t('FILTER.ATTRIBUTES.CONTACT'),
      inputType: 'asyncSearchSelect',
      searchOptions: searchContactOptions,
      searchPlaceholder: t('FILTER.CONTACT_SEARCH_PLACEHOLDER'),
      dataType: 'number',
      filterOperators: equalityOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.DISPLAY_ID,
      value: CONVERSATION_ATTRIBUTES.DISPLAY_ID,
      attributeName: t('FILTER.ATTRIBUTES.CONVERSATION_IDENTIFIER'),
      label: t('FILTER.ATTRIBUTES.CONVERSATION_IDENTIFIER'),
      inputType: 'number',
      dataType: 'number',
      filterOperators: containmentOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.LABELS,
      value: CONVERSATION_ATTRIBUTES.LABELS,
      attributeName: t('FILTER.ATTRIBUTES.LABELS'),
      label: t('FILTER.ATTRIBUTES.LABELS'),
      inputType: 'multiSelect',
      options: labels.value.map(label => {
        return {
          id: label.title,
          name: label.title,
          icon: h('span', {
            class: `rounded-full`,
            style: {
              backgroundColor: label.color,
              height: '6px',
              width: '6px',
            },
          }),
        };
      }),
      dataType: 'text',
      filterOperators: labelOperators.value,
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.ONLY_SYSTEM_LABELS,
      value: CONVERSATION_ATTRIBUTES.ONLY_SYSTEM_LABELS,
      attributeName: t('FILTER.ATTRIBUTES.ONLY_SYSTEM_LABELS'),
      label: t('FILTER.ATTRIBUTES.ONLY_SYSTEM_LABELS'),
      inputType: 'plainText',
      dataType: 'text',
      filterOperators: [
        {
          ...operators.value.is_present,
          label: t('FILTER.OPERATOR_LABELS.only_system_labels'),
        },
      ],
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.CSAT_RATING,
      value: CONVERSATION_ATTRIBUTES.CSAT_RATING,
      attributeName: t('FILTER.ATTRIBUTES.CSAT_RATING'),
      label: t('FILTER.ATTRIBUTES.CSAT_RATING'),
      inputType: 'searchSelect',
      options: ['rated', 'positive', 'negative', 'not_rated'].map(id => ({
        id,
        name: t(`FILTER.CSAT_RATING_OPTIONS.${id}`),
      })),
      dataType: 'text',
      filterOperators: [operators.value.equal_to],
      attributeModel: 'standard',
    },
    {
      attributeKey: CONVERSATION_ATTRIBUTES.CREATED_AT,
      value: CONVERSATION_ATTRIBUTES.CREATED_AT,
      attributeName: t('FILTER.ATTRIBUTES.CREATED_AT'),
      label: t('FILTER.ATTRIBUTES.CREATED_AT'),
      inputType: 'date',
      dataType: 'text',
      filterOperators: dateOperators.value,
      attributeModel: 'standard',
    },
    ...customFilterTypes.value,
  ]);

  // The same attributes, grouped into sections with a leading icon, for the attribute picker.
  const attributeFilterTypes = computed(() =>
    groupFilterTypes(filterTypes.value, t)
  );

  return { filterTypes, attributeFilterTypes };
}
