import RoutingTypesAPI from '../../api/routingTypes';
import * as types from '../mutation-types';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getRoutingTypes(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isFetching: true });
    try {
      const response = await RoutingTypesAPI.get();
      commit(types.default.SET_ROUTING_TYPES, response.data.payload); // было response.data
    } finally {
      commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isFetching: false });
    }
  },
  create: async ({ commit }, routingType) => {
    commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isCreating: true });
    try {
      const response = await RoutingTypesAPI.create(routingType);
      commit(
        types.default.ADD_ROUTING_TYPE,
        response.data.payload ?? response.data
      ); // проверьте формат ответа create-контроллера
    } finally {
      commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...routingType }) => {
    commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isUpdating: true });
    try {
      const response = await RoutingTypesAPI.update(id, routingType);
      commit(
        types.default.EDIT_ROUTING_TYPE,
        response.data.payload ?? response.data
      );
    } finally {
      commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isUpdating: false });
    }
  },
  delete: async ({ commit }, id) => {
    commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isDeleting: true });
    try {
      await RoutingTypesAPI.delete(id);
      commit(types.default.DELETE_ROUTING_TYPE, id);
    } finally {
      commit(types.default.SET_ROUTING_TYPES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.default.SET_ROUTING_TYPES_UI_FLAG](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  [types.default.SET_ROUTING_TYPES](_state, data) {
    _state.records = data;
  },
  [types.default.ADD_ROUTING_TYPE](_state, item) {
    _state.records.push(item);
  },
  [types.default.EDIT_ROUTING_TYPE](_state, item) {
    _state.records = _state.records.map(r => (r.id === item.id ? item : r));
  },
  [types.default.DELETE_ROUTING_TYPE](_state, id) {
    _state.records = _state.records.filter(r => r.id !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
