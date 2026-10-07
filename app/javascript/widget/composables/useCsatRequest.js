import { computed } from 'vue';
import { useStore } from 'vuex';
import { CSAT_DISPLAY_TYPES } from 'shared/constants/messages';

export function useCsatRequest() {
  const store = useStore();
  const conversationSize = computed(
    () => store.getters['conversation/getConversationSize']
  );

  const canRequestCsat = computed(
    () =>
      conversationSize.value > 0 &&
      window.chatwootWebChannel?.csatSurveyEnabled &&
      window.chatwootWebChannel?.csatDisplayType ===
        CSAT_DISPLAY_TYPES.LIKE_DISLIKE
  );

  return { canRequestCsat };
}
