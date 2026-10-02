<script setup>
import { h, ref, watch, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import Editor from 'next/Editor/Editor.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from 'next/input/DurationInput.vue';
import TextArea from 'next/textarea/TextArea.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const { t } = useI18n();
const duration = ref(0);
const unit = ref(DURATION_UNITS.MINUTES);
const message = ref('');
const labelToApply = ref({});
const ignoreWaiting = ref(false);
const isEnabled = ref(false);
const isSubmitting = ref(false);
const splitReasons = ref(false);
const messageAgent = ref('');
const messageClient = ref('');
const isInitialized = ref(false);

const pendingDuration = ref(0);
const pendingUnit = ref(DURATION_UNITS.MINUTES);
const pendingMessage = ref('');
const isEnabledPending = ref(false);
const isPendingSubmitting = ref(false);
const isPendingInitialized = ref(false);

const { currentAccount, updateAccount } = useAccount();

const labels = useMapGetter('labels/getLabels');

const labelOptions = computed(() =>
  labels.value?.length
    ? labels.value.map(label => ({
        id: label.title,
        name: label.title,
        icon: h('span', {
          class: `size-[12px] ring-1 ring-n-alpha-1 dark:ring-white/20 ring-inset rounded-sm`,
          style: { backgroundColor: label.color },
        }),
      }))
    : []
);

const selectedLabelName = computed(() => {
  return labelToApply.value?.name ?? null;
});

watch(
  [currentAccount, labelOptions],
  () => {
    const {
      auto_resolve_after,
      auto_resolve_message,
      auto_resolve_ignore_waiting,
      auto_resolve_label,
      auto_resolve_split_reasons,
      auto_resolve_message_agent,
      auto_resolve_message_client,
      auto_resolve_pending_after,
      auto_resolve_pending_message,
    } = currentAccount.value?.settings || {};

    duration.value = auto_resolve_after;
    ignoreWaiting.value = auto_resolve_ignore_waiting;

    if (!isInitialized.value) {
      splitReasons.value = auto_resolve_split_reasons || false;

      if (splitReasons.value) {
        messageAgent.value = auto_resolve_message_agent || '';
        messageClient.value = auto_resolve_message_client || '';
      } else {
        message.value = auto_resolve_message || '';
      }

      isInitialized.value = true;
    }

    labelToApply.value = labelOptions.value.find(
      option => option.name === auto_resolve_label
    );

    if (duration.value) {
      if (duration.value % (24 * 60) === 0) {
        unit.value = DURATION_UNITS.DAYS;
      } else if (duration.value % 60 === 0) {
        unit.value = DURATION_UNITS.HOURS;
      } else {
        unit.value = DURATION_UNITS.MINUTES;
      }

      isEnabled.value = true;
    }

    pendingDuration.value = auto_resolve_pending_after;

    if (!isPendingInitialized.value) {
      pendingMessage.value = auto_resolve_pending_message || '';
      isPendingInitialized.value = true;
    }

    if (pendingDuration.value) {
      if (pendingDuration.value % (24 * 60) === 0) {
        pendingUnit.value = DURATION_UNITS.DAYS;
      } else if (pendingDuration.value % 60 === 0) {
        pendingUnit.value = DURATION_UNITS.HOURS;
      } else {
        pendingUnit.value = DURATION_UNITS.MINUTES;
      }

      isEnabledPending.value = true;
    }
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async (settings, { isPending = false } = {}) => {
  const submittingRef = isPending ? isPendingSubmitting : isSubmitting;
  try {
    submittingRef.value = true;
    await updateAccount(settings, { silent: true });
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.API.ERROR'));
  } finally {
    submittingRef.value = false;
  }
};

const handleSubmit = async () => {
  if (duration.value < 10) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.ERROR'));
    return;
  }

  const settings = {
    auto_resolve_after: duration.value,
    auto_resolve_ignore_waiting: ignoreWaiting.value,
    auto_resolve_label: selectedLabelName.value,
    auto_resolve_split_reasons: splitReasons.value,
  };

  if (splitReasons.value) {
    settings.auto_resolve_message_agent = messageAgent.value;
    settings.auto_resolve_message_client = messageClient.value;
    settings.auto_resolve_message = null;
  } else {
    settings.auto_resolve_message = message.value;
    settings.auto_resolve_message_agent = null;
    settings.auto_resolve_message_client = null;
  }

  await updateAccountSettings(settings);
};

const handleDisable = async () => {
  duration.value = null;
  message.value = '';
  splitReasons.value = false;
  messageAgent.value = '';
  messageClient.value = '';

  return updateAccountSettings({
    auto_resolve_after: null,
    auto_resolve_message: '',
    auto_resolve_ignore_waiting: false,
    auto_resolve_label: null,
    auto_resolve_split_reasons: false,
    auto_resolve_message_agent: null,
    auto_resolve_message_client: null,
  });
};

const toggleAutoResolve = async () => {
  if (!isEnabled.value) handleDisable();
};

const handlePendingSubmit = async () => {
  if (pendingDuration.value < 10) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.DURATION.ERROR'));
    return;
  }

  await updateAccountSettings(
    {
      auto_resolve_pending_after: pendingDuration.value,
      auto_resolve_pending_message: pendingMessage.value,
    },
    { isPending: true }
  );
};

const handlePendingDisable = async () => {
  pendingDuration.value = null;
  pendingMessage.value = '';

  return updateAccountSettings(
    {
      auto_resolve_pending_after: null,
      auto_resolve_pending_message: '',
    },
    { isPending: true }
  );
};

const togglePendingAutoResolve = async () => {
  if (!isEnabledPending.value) handlePendingDisable();
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.TITLE') }}
        </h3>
        <div class="flex justify-end">
          <Switch v-model="isEnabled" @change="toggleAutoResolve" />
        </div>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.NOTE') }}
      </p>
    </div>

    <div v-if="isEnabled" class="px-5 py-4">
      <form class="grid gap-5" @submit.prevent="handleSubmit">
        <WithLabel
          :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.LABEL')"
          :help-message="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.DURATION.HELP')"
        >
          <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
            <DurationInput
              v-model="duration"
              v-model:unit="unit"
              min="0"
              max="1438560"
              class="w-full"
            />
          </div>
        </WithLabel>
        <div class="flex items-center justify-between text-sm">
          <span>
            {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.SPLIT_REASONS') }}
          </span>
          <Switch v-model="splitReasons" />
        </div>
        <WithLabel
          v-if="!splitReasons"
          :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.LABEL')"
          :help-message="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.HELP')"
        >
          <Editor
            v-model="message"
            class="w-full"
            channel-type="Context::NoToolbar"
            enable-variables
            :enable-canned-responses="false"
            :show-character-count="false"
            :placeholder="
              t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.PLACEHOLDER')
            "
          />
        </WithLabel>
        <template v-else>
          <WithLabel
            :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.AGENT_LABEL')"
          >
            <Editor
              v-model="messageAgent"
              class="w-full"
              channel-type="Context::NoToolbar"
              enable-variables
              :enable-canned-responses="false"
              :show-character-count="false"
              :placeholder="
                t(
                  'GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.AGENT.PLACEHOLDER'
                )
              "
            />
          </WithLabel>
          <WithLabel
            :label="
              t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.CLIENT_LABEL')
            "
          >
            <Editor
              v-model="messageClient"
              class="w-full"
              channel-type="Context::NoToolbar"
              enable-variables
              :enable-canned-responses="false"
              :show-character-count="false"
              :placeholder="
                t(
                  'GENERAL_SETTINGS.FORM.AUTO_RESOLVE.MESSAGE.CLIENT.PLACEHOLDER'
                )
              "
            />
          </WithLabel>
        </template>
        <WithLabel :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.PREFERENCES')">
          <div
            class="rounded-xl border border-n-weak bg-n-solid-1 w-full text-sm text-n-slate-12 divide-y divide-n-weak"
          >
            <div class="p-3 h-12 flex items-center justify-between">
              <span>
                {{
                  t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.IGNORE_WAITING.LABEL')
                }}
              </span>
              <Switch v-model="ignoreWaiting" />
            </div>
            <div class="p-3 h-12 flex items-center justify-between">
              <span>
                {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.LABEL.LABEL') }}
              </span>
              <SingleSelect
                v-model="labelToApply"
                :options="labelOptions"
                :placeholder="
                  $t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.LABEL.PLACEHOLDER')
                "
                placeholder-icon="i-lucide-chevron-down"
                placeholder-trailing-icon
                variant="faded"
              />
            </div>
          </div>
        </WithLabel>
        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            :is-loading="isSubmitting"
            :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE.UPDATE_BUTTON')"
          />
        </div>
      </form>
    </div>
  </div>

  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full">
        <h3 class="text-heading-2 text-n-slate-12">
          {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.TITLE') }}
        </h3>
        <div class="flex justify-end">
          <Switch
            v-model="isEnabledPending"
            @change="togglePendingAutoResolve"
          />
        </div>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        {{ t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.NOTE') }}
      </p>
    </div>

    <div v-if="isEnabledPending" class="px-5 py-4">
      <form class="grid gap-5" @submit.prevent="handlePendingSubmit">
        <WithLabel
          :label="
            t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.DURATION.LABEL')
          "
          :help-message="
            t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.DURATION.HELP')
          "
        >
          <div class="gap-2 w-full grid grid-cols-[3fr_1fr]">
            <DurationInput
              v-model="pendingDuration"
              v-model:unit="pendingUnit"
              min="0"
              max="1438560"
              class="w-full"
            />
          </div>
        </WithLabel>

        <WithLabel
          :label="t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.MESSAGE.LABEL')"
          :help-message="
            t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.MESSAGE.HELP')
          "
        >
          <TextArea
            v-model="pendingMessage"
            class="w-full"
            :placeholder="
              t(
                'GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.MESSAGE.PLACEHOLDER'
              )
            "
          />
        </WithLabel>

        <div class="flex gap-2">
          <NextButton
            blue
            type="submit"
            :is-loading="isPendingSubmitting"
            :label="
              t('GENERAL_SETTINGS.FORM.AUTO_RESOLVE_PENDING.UPDATE_BUTTON')
            "
          />
        </div>
      </form>
    </div>
  </div>
</template>
