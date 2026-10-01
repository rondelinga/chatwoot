import * as types from '../mutation-types';
import UserNotificationSettings from '../../api/userNotificationSettings';

const DEFAULT_SOUND_SETTINGS = {
  new_conversation_sound_enabled: true,
  new_conversation_sound: 'bell',
  new_conversation_volume: 80,
  new_conversation_custom_sound_id: null,
  new_conversation_custom_sound_url: null,
  new_message_sound_enabled: true,
  new_message_sound: 'pop',
  new_message_volume: 60,
  new_message_custom_sound_id: null,
  new_message_custom_sound_url: null,
  custom_sounds: [],
};

const state = {
  record: {},
  uiFlags: {
    isFetching: false,
    isUpdating: false,
  },
};

export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getSelectedEmailFlags: $state => {
    return $state.record.selected_email_flags;
  },
  getSelectedPushFlags: $state => {
    return $state.record.selected_push_flags;
  },
  getNotificationDisplayDuration: $state => {
    return $state.record.notification_display_duration ?? 6;
  },
  getSoundSettings: $state => {
    return {
      ...DEFAULT_SOUND_SETTINGS,
      ...$state.record,
      custom_sounds: $state.record.custom_sounds || [],
    };
  },
};

const buildUpdatePayload = params => {
  const notificationSettings = {};
  const emailFlags = params.selectedEmailFlags ?? params.selected_email_flags;
  const pushFlags = params.selectedPushFlags ?? params.selected_push_flags;
  const displayDuration =
    params.notificationDisplayDuration ?? params.notification_display_duration;

  if (emailFlags !== undefined) {
    notificationSettings.selected_email_flags = emailFlags;
  }
  if (pushFlags !== undefined) {
    notificationSettings.selected_push_flags = pushFlags;
  }
  if (displayDuration !== undefined) {
    notificationSettings.notification_display_duration = displayDuration;
  }

  [
    'new_conversation_sound_enabled',
    'new_conversation_sound',
    'new_conversation_volume',
    'new_conversation_custom_sound_id',
    'new_message_sound_enabled',
    'new_message_sound',
    'new_message_volume',
    'new_message_custom_sound_id',
  ].forEach(key => {
    if (params[key] !== undefined) {
      notificationSettings[key] = params[key];
    }
  });

  return notificationSettings;
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, { isFetching: true });
    try {
      const response = await UserNotificationSettings.get();
      commit(types.default.SET_USER_NOTIFICATION, response.data);
      commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, {
        isFetching: false,
      });
    } catch (error) {
      commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, {
        isFetching: false,
      });
    }
  },

  update: async ({ commit }, params) => {
    commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, { isUpdating: true });
    try {
      const response = await UserNotificationSettings.update({
        notification_settings: buildUpdatePayload(params),
      });
      commit(types.default.SET_USER_NOTIFICATION, response.data);
      commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, {
        isUpdating: false,
      });
    } catch (error) {
      commit(types.default.SET_USER_NOTIFICATION_UI_FLAG, {
        isUpdating: false,
      });
      throw error;
    }
  },
};

export const mutations = {
  [types.default.SET_USER_NOTIFICATION_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.default.SET_USER_NOTIFICATION]: ($state, data) => {
    $state.record = data;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
