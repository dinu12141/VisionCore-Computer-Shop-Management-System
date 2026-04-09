<template>
  <div class="row q-gutter-sm items-center">
    <!-- Save Draft -->
    <q-btn
      v-if="status === 'draft' || status === ''"
      outline
      color="grey-5"
      icon="save"
      label="Save Draft"
      :loading="saving"
      :disable="disabled"
      @click="$emit('save-draft')"
    />

    <!-- Post -->
    <q-btn
      v-if="status === 'draft' || status === ''"
      color="positive"
      icon="check_circle"
      label="Post Document"
      :loading="posting"
      :disable="disabled"
      @click="confirmPost"
    >
      <q-tooltip>Post to ledger — this action cannot be undone easily</q-tooltip>
    </q-btn>

    <!-- Cancel / Discard (Restricted to Admin for existing documents) -->
    <q-btn
      v-if="status === 'draft' && isAdmin"
      flat
      color="negative"
      icon="cancel"
      label="Discard"
      @click="$emit('cancel')"
    />

    <!-- Cancel Posted Doc (Restricted to Admin/Manager only) -->
    <q-btn
      v-if="status === 'posted' && isAdminOrManager"
      outline
      color="negative"
      icon="undo"
      label="Cancel & Reverse"
      @click="confirmCancel"
    >
      <q-tooltip>Creates reversal entries in the ledger</q-tooltip>
    </q-btn>

    <!-- Posted badge -->
    <q-chip v-if="status === 'posted'" color="green-9" text-color="white" icon="verified" dense>
      POSTED
    </q-chip>

    <q-chip v-if="status === 'cancelled'" color="red-9" text-color="white" icon="block" dense>
      CANCELLED
    </q-chip>
  </div>
</template>

<script setup>
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/stores/auth'
import { computed } from 'vue'

const auth = useAuthStore()
const isAdmin = computed(() => auth.hasAnyRole(['admin', 'manager', 'inventory']))
const isAdminOrManager = computed(() => auth.hasAnyRole(['admin', 'manager']))

defineProps({
  status: { type: String, default: '' },
  saving: { type: Boolean, default: false },
  posting: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['save-draft', 'post', 'cancel', 'cancel-posted'])
const $q = useQuasar()

function confirmPost() {
  $q.dialog({
    title: 'Confirm Post',
    message:
      'Once posted, this document will create ledger entries and update stock levels. This cannot be directly undone. Continue?',
    cancel: true,
    persistent: true,
    dark: $q.dark.isActive,
    color: 'positive',
  }).onOk(() => {
    emit('post')
  })
}

function confirmCancel() {
  $q.dialog({
    title: 'Cancel & Reverse Document',
    message:
      "This will create reversal entries in the stock ledger to undo this document's effect. Continue?",
    cancel: true,
    persistent: true,
    dark: $q.dark.isActive,
    color: 'negative',
  }).onOk(() => {
    emit('cancel-posted')
  })
}
</script>
