<script setup>
import { ref, computed, nextTick, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ActiveFilterChip from './Filters/v3/ActiveFilterChip.vue';
import AddFilterChip from './Filters/v3/AddFilterChip.vue';
import SelectedFilterChip from './Filters/v3/SelectedFilterChip.vue';
import TimeRangeFilterChip from './Filters/v3/TimeRangeFilterChip.vue';
import ReportFilterPresets from './ReportFilterPresets.vue';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import {
  DEFAULT_TIME_RANGE,
  GROUP_BY_TRANSLATION_KEYS,
  getGroupByOptions,
  getInitialDateRange,
  getUnixWithTime,
  resolveGroupBy,
} from '../helpers/advancedReportFilterHelper';
import {
  firstIds,
  idsOf,
  parsePresetFilters,
  pickByIds,
  serializePresetDateRange,
} from '../helpers/reportFilterPresetHelper';

const props = defineProps({
  showGroupByFilter: { type: Boolean, default: false },
  showAgentsFilter: { type: Boolean, default: false },
  showInboxFilter: { type: Boolean, default: false },
  showTeamFilter: { type: Boolean, default: false },
  showLabelsFilter: { type: Boolean, default: false },
  showTimeRangeFilter: { type: Boolean, default: false },
  showBusinessHoursSwitch: { type: Boolean, default: true },
  // Enables saved filter presets for the page
  section: { type: String, default: '' },
  // Filters owned by the page (e.g. CSAT chips) that are saved with presets
  extraFilters: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['filterChange', 'applyExtraFilters']);

const { t } = useI18n();
const store = useStore();

const ENTITY_FILTERS = {
  agents: {
    stateKey: 'selectedAgents',
    getter: 'agents/getAgents',
    action: 'agents/get',
    labelKey: 'REPORT.FILTERS.AGENTS',
  },
  inboxes: {
    stateKey: 'selectedInbox',
    getter: 'inboxes/getInboxes',
    action: 'inboxes/get',
    labelKey: 'REPORT.FILTERS.INBOXES',
  },
  teams: {
    stateKey: 'selectedTeam',
    getter: 'teams/getTeams',
    action: 'teams/get',
    labelKey: 'REPORT.FILTERS.TEAMS',
  },
  labels: {
    stateKey: 'selectedLabel',
    getter: 'labels/getLabels',
    action: 'labels/get',
    labelKey: 'REPORT.FILTERS.LABELS',
  },
};

const saved = store.getters.getReportFilters;

const selectedRangeType = ref(
  saved.selectedDateRange || DATE_RANGE_TYPES.TODAY
);
const customDateRange = ref(
  getInitialDateRange(selectedRangeType.value, saved.customDateRange)
);
const groupBy = ref(
  resolveGroupBy(selectedRangeType.value, saved.selectedGroupByFilter)
);
const businessHoursSelected = ref(saved.businessHoursSelected ?? false);
const timeRange = ref(saved.selectedTimeRange || { ...DEFAULT_TIME_RANGE });
const selectedItems = ref(
  Object.fromEntries(
    Object.entries(ENTITY_FILTERS).map(([type, { stateKey }]) => [
      type,
      Array.isArray(saved[stateKey]) ? saved[stateKey] : [],
    ])
  )
);
const showFilterMenu = ref(false);
const showGroupByDropdown = ref(false);

const visibleFilterTypes = computed(() =>
  [
    props.showAgentsFilter && 'agents',
    props.showInboxFilter && 'inboxes',
    props.showTeamFilter && 'teams',
    props.showLabelsFilter && 'labels',
  ].filter(Boolean)
);

const getSource = type => store.getters[ENTITY_FILTERS[type].getter] || [];

const filterMenuItems = computed(() =>
  visibleFilterTypes.value.map(type => {
    const selectedIds = selectedItems.value[type].map(item => item.id);
    return {
      id: type,
      name: t(ENTITY_FILTERS[type].labelKey),
      type,
      options: getSource(type)
        .filter(item => !selectedIds.includes(item.id))
        .map(item => ({ id: item.id, name: item.name || item.title, type })),
    };
  })
);

const selectedChips = computed(() =>
  visibleFilterTypes.value.flatMap(type =>
    selectedItems.value[type].map(item => ({
      type,
      id: item.id,
      name: item.name || item.title,
    }))
  )
);

const groupByOptions = computed(() =>
  getGroupByOptions(selectedRangeType.value).map(option => ({
    id: option.id,
    name: t(GROUP_BY_TRANSLATION_KEYS[option.period]),
  }))
);

const showGroupByChip = computed(
  () => props.showGroupByFilter && groupByOptions.value.length > 1
);

const groupByName = computed(
  () =>
    groupByOptions.value.find(option => option.id === groupBy.value.id)?.name
);

const emitChange = () => {
  const [startDate, endDate] = customDateRange.value;
  const { agents, inboxes, teams, labels } = selectedItems.value;

  store.dispatch('updateReportFilters', {
    selectedDateRange: selectedRangeType.value,
    selectedGroupByFilter: groupBy.value,
    customDateRange: customDateRange.value,
    businessHoursSelected: businessHoursSelected.value,
    selectedAgents: agents,
    selectedInbox: inboxes,
    selectedTeam: teams,
    selectedLabel: labels,
    selectedTimeRange: timeRange.value,
  });

  emit('filterChange', {
    from: getUnixWithTime(startDate, timeRange.value.since),
    to: getUnixWithTime(endDate, timeRange.value.until),
    groupBy: groupBy.value,
    businessHours: businessHoursSelected.value,
    selectedAgents: agents,
    selectedInbox: inboxes,
    selectedTeam: teams,
    selectedLabel: labels,
    timeRange: timeRange.value,
  });
};

const visibleIds = type =>
  visibleFilterTypes.value.includes(type)
    ? idsOf(selectedItems.value[type])
    : [];

const presetFilters = computed(() => {
  const extra = props.extraFilters;

  return {
    ...serializePresetDateRange(selectedRangeType.value, customDateRange.value),
    groupById: groupBy.value.id,
    businessHours: businessHoursSelected.value,
    timeRange: timeRange.value,
    agentIds: firstIds(visibleIds('agents'), extra.agentIds, extra.user_ids),
    inboxIds: firstIds(visibleIds('inboxes'), extra.inboxIds, extra.inbox_id),
    teamIds: firstIds(visibleIds('teams'), extra.teamIds, extra.team_id),
    labelIds: firstIds(visibleIds('labels'), extra.labelIds),
    ratingValue: extra.rating ?? null,
    extra,
  };
});

const applyPreset = async filters => {
  const preset = parsePresetFilters(filters);
  if (preset.range) {
    selectedRangeType.value = preset.range.rangeType;
    customDateRange.value = preset.range.dateRange;
  }
  groupBy.value = resolveGroupBy(selectedRangeType.value, {
    id: preset.groupById ?? groupBy.value.id,
  });
  businessHoursSelected.value = preset.businessHours;
  if (preset.timeRange) timeRange.value = preset.timeRange;

  await Promise.all(
    Object.values(ENTITY_FILTERS).map(({ action }) => store.dispatch(action))
  );

  const presetIds = {
    agents: preset.agentIds,
    inboxes: preset.inboxIds,
    teams: preset.teamIds,
    labels: preset.labelIds,
  };
  visibleFilterTypes.value.forEach(type => {
    selectedItems.value[type] = pickByIds(getSource(type), presetIds[type]);
  });

  emit('applyExtraFilters', {
    ...preset.extra,
    user_ids: preset.agentIds,
    inbox_id: preset.inboxIds,
    team_id: preset.teamIds,
    rating: preset.ratingValue,
  });

  // Let the page apply its own filters before the combined change is emitted
  await nextTick();
  emitChange();
};

const onDateRangeChange = ([startDate, endDate, rangeType]) => {
  customDateRange.value = [startDate, endDate];
  selectedRangeType.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  groupBy.value = resolveGroupBy(selectedRangeType.value, groupBy.value);
  emitChange();
};

const onGroupByChange = ({ id }) => {
  groupBy.value = resolveGroupBy(selectedRangeType.value, { id });
  showGroupByDropdown.value = false;
  emitChange();
};

const onTimeRangeChange = value => {
  timeRange.value = value;
  emitChange();
};

const addFilter = ({ type, id }) => {
  const item = getSource(type).find(source => source.id === id);
  selectedItems.value[type] = [...selectedItems.value[type], item];
  emitChange();
};

const removeFilter = (type, id) => {
  selectedItems.value[type] = selectedItems.value[type].filter(
    item => item.id !== id
  );
  emitChange();
};

const clearAllFilters = () => {
  visibleFilterTypes.value.forEach(type => {
    selectedItems.value[type] = [];
  });
  showFilterMenu.value = false;
  emitChange();
};

onMounted(() => {
  visibleFilterTypes.value.forEach(type =>
    store.dispatch(ENTITY_FILTERS[type].action)
  );
  emitChange();
});
</script>

<template>
  <div class="flex flex-col w-full gap-3">
    <ReportFilterPresets
      v-if="section"
      :filters="presetFilters"
      @apply="applyPreset"
    />
    <div class="flex flex-col w-full gap-3 lg:flex-row">
      <WootDatePicker
        v-model:date-range="customDateRange"
        v-model:range-type="selectedRangeType"
        @date-range-changed="onDateRangeChange"
      />

      <div class="flex flex-wrap items-center w-full gap-2">
        <TimeRangeFilterChip
          v-if="showTimeRangeFilter"
          :since="timeRange.since"
          :until="timeRange.until"
          @change="onTimeRangeChange"
        />

        <ActiveFilterChip
          v-if="showGroupByChip"
          :id="groupBy.id"
          :name="groupByName || $t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')"
          type="groupBy"
          :options="groupByOptions"
          :active-filter-type="showGroupByDropdown ? 'groupBy' : ''"
          :show-menu="showGroupByDropdown"
          :placeholder="$t('REPORT.GROUP_BY_FILTER_DROPDOWN_LABEL')"
          :show-clear-filter="false"
          @toggle-dropdown="showGroupByDropdown = !showGroupByDropdown"
          @close-dropdown="showGroupByDropdown = false"
          @add-filter="onGroupByChange"
        />

        <div
          v-if="showBusinessHoursSwitch"
          class="flex items-center flex-shrink-0 ms-auto"
        >
          <span class="mx-2 text-sm whitespace-nowrap">
            {{ $t('REPORT.BUSINESS_HOURS') }}
          </span>
          <ToggleSwitch v-model="businessHoursSelected" @change="emitChange" />
        </div>
      </div>
    </div>

    <div
      v-if="visibleFilterTypes.length"
      class="flex flex-wrap items-center gap-2"
    >
      <SelectedFilterChip
        v-for="chip in selectedChips"
        :key="`${chip.type}-${chip.id}`"
        :name="chip.name"
        @remove="removeFilter(chip.type, chip.id)"
      />

      <div v-if="selectedChips.length" class="w-px h-5 border border-n-weak" />

      <AddFilterChip
        placeholder-i18n-key="REPORT.FILTERS.INPUT_PLACEHOLDER"
        :name="$t('REPORT.FILTERS.ADD_FILTER')"
        :menu-option="filterMenuItems"
        :show-menu="showFilterMenu"
        :empty-state-message="$t('REPORT.FILTERS.NO_FILTER')"
        @toggle-dropdown="showFilterMenu = !showFilterMenu"
        @close-dropdown="showFilterMenu = false"
        @add-filter="addFilter"
      />

      <FilterButton
        v-if="selectedChips.length"
        :button-text="$t('REPORT.FILTERS.CLEAR_ALL')"
        @click="clearAllFilters"
      />
    </div>
  </div>
</template>
