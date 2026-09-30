<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';
import { useAlert } from 'dashboard/composables';
import AddRoutingType from './AddRoutingType.vue';
import EditRoutingType from './EditRoutingType.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedRoutingType = ref({});
const searchQuery = ref('');
const loading = ref({});

const records = computed(() => getters['routingTypes/getRoutingTypes'].value);
const attributes = computed(() => getters['attributes/getAttributes'].value);

const formatAttributeValue = item => {
  const attribute = attributes.value.find(
    attr => attr.attribute_key === item.attribute_key
  );

  if (attribute?.attribute_display_type === 'checkbox') {
    return item.attribute_value === 'true'
      ? t('FILTER.ATTRIBUTE_LABELS.TRUE')
      : t('FILTER.ATTRIBUTE_LABELS.FALSE');
  }

  return item.attribute_value;
};

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, [
    { name: 'name', weight: 4 },
    'attribute_key',
    'attribute_value',
  ]);
});

const uiFlags = computed(() => getters['routingTypes/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedRoutingType.value.name}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = item => {
  selectedRoutingType.value = item;
  showEditPopup.value = true;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = item => {
  selectedRoutingType.value = item;
  showDeleteConfirmationPopup.value = true;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteRoutingType = async id => {
  try {
    await store.dispatch('routingTypes/delete', id);
    useAlert(t('ROUTING_TYPES.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('ROUTING_TYPES.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedRoutingType.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedRoutingType.value.id] = true;
  closeDeletePopup();
  deleteRoutingType(selectedRoutingType.value.id);
};

const tableHeaders = computed(() => [
  t('ROUTING_TYPES.LIST.TABLE_HEADER.NAME'),
  t('ROUTING_TYPES.LIST.TABLE_HEADER.ATTRIBUTE_KEY'),
  t('ROUTING_TYPES.LIST.TABLE_HEADER.ATTRIBUTE_VALUE'),
  t('ROUTING_TYPES.LIST.TABLE_HEADER.ACTION'),
]);

onBeforeMount(() => {
  store.dispatch('routingTypes/get');
  store.dispatch('attributes/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('ROUTING_TYPES.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('ROUTING_TYPES.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('ROUTING_TYPES.HEADER')"
        :description="$t('ROUTING_TYPES.DESCRIPTION')"
        :link-text="$t('ROUTING_TYPES.LEARN_MORE')"
        :search-placeholder="$t('ROUTING_TYPES.SEARCH_PLACEHOLDER')"
        feature-name="routingTypes"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('ROUTING_TYPES.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('ROUTING_TYPES.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('ROUTING_TYPES.NO_RESULTS')
            : $t('ROUTING_TYPES.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="item in items" :key="item.id" :item="item">
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ item.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ item.attribute_key }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ formatAttributeValue(item) }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <div class="flex gap-3 flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('ROUTING_TYPES.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[item.id]"
                    @click="openEditPopup(item)"
                  />
                  <Button
                    v-tooltip.top="$t('ROUTING_TYPES.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[item.id]"
                    @click="openDeletePopup(item)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddRoutingType @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditRoutingType
        :selected-routing-type="selectedRoutingType"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('ROUTING_TYPES.DELETE.CONFIRM.TITLE')"
      :message="$t('ROUTING_TYPES.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('ROUTING_TYPES.DELETE.CONFIRM.YES')"
      :reject-text="$t('ROUTING_TYPES.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
