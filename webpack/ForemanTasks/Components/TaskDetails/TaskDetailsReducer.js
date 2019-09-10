import Immutable from 'seamless-immutable';
import {
  FOREMAN_TASK_DETAILS_FETCH_TASK_REQUEST,
  FOREMAN_TASK_DETAILS_FETCH_TASK_SUCCESS,
  FOREMAN_TASK_DETAILS_STOP_POLLING,
  FOREMAN_TASK_DETAILS_START_POLLING,
  FOREMAN_TASK_DETAILS_TOGGLE_UNLOCK_MODAL,
  FOREMAN_TASK_DETAILS_TOGGLE_FORCE_UNLOCK_MODAL,
} from './TaskDetailsConstants';

const initialState = Immutable({});

export default (state = initialState, action) => {
  const { type, payload } = action;
  let { taskReload, timeoutId } = state;

  switch (type) {
    case FOREMAN_TASK_DETAILS_FETCH_TASK_REQUEST:
      return state.set('loading', true);
    case FOREMAN_TASK_DETAILS_FETCH_TASK_SUCCESS:
      if (payload.state === 'stopped') {
        clearTimeout(state.timeoutId);
        taskReload = false;
        timeoutId = null;
      }
      return state.merge({
        loading: false,
        ...payload,
        taskReload,
        timeoutId,
      });
    case FOREMAN_TASK_DETAILS_STOP_POLLING:
      return state.merge({ taskReload: false, timeoutId: null });
    case FOREMAN_TASK_DETAILS_START_POLLING:
      clearTimeout(state.timeoutId);
      return state.merge({ taskReload: true, timeoutId: payload.timeoutId });
    case FOREMAN_TASK_DETAILS_TOGGLE_UNLOCK_MODAL:
      return state.set('showUnlockModal', !state.showUnlockModal);
    case FOREMAN_TASK_DETAILS_TOGGLE_FORCE_UNLOCK_MODAL:
      return state.set('showForceUnlockModal', !state.showForceUnlockModal);
    default:
      return state;
  }
};
