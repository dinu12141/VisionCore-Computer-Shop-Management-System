<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    persistent
  >
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      style="min-width: 550px; border-radius: 12px"
    >
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          <q-icon name="send" color="primary" class="q-mr-sm" />
          Email Purchase Order
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-md">
        <div class="q-mb-md text-caption text-grey-5">
          Review the details below before sending the Purchase Order document to the supplier.
        </div>

        <div class="row q-col-gutter-sm">
          <div class="col-12">
            <q-input
              :dark="$q.dark.isActive"
              outlined
              label="Recipient Email"
              v-model="email"
              readonly
              :bg-color="$q.dark.isActive ? 'grey-10' : 'grey-2'"
            >
              <template v-slot:prepend>
                <q-icon name="alternate_email" color="primary" />
              </template>
            </q-input>
          </div>

          <div class="col-12">
            <q-input
              :dark="$q.dark.isActive"
              outlined
              label="Subject"
              v-model="subject"
              readonly
              :bg-color="$q.dark.isActive ? 'grey-10' : 'grey-2'"
            />
          </div>

          <div class="col-12 q-mt-sm">
            <q-input
              :dark="$q.dark.isActive"
              outlined
              type="textarea"
              label="Custom Message for Supplier"
              v-model="customMessage"
              rows="5"
              placeholder="e.g. Please confirm delivery for next Monday. Thank you."
            />
          </div>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat label="Back" color="grey-5" v-close-popup />
        <q-btn
          color="primary"
          label="Send to Supplier"
          icon="forward_to_inbox"
          :loading="sending"
          class="q-px-md"
          @click="onSend"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed } from 'vue'
import { sendPOEmail } from 'src/services/inventoryService'
import { useQuasar } from 'quasar'

const props = defineProps({
  modelValue: Boolean,
  document: Object,
})

const emit = defineEmits(['update:modelValue', 'sent'])
const $q = useQuasar()

const sending = ref(false)
const customMessage = ref('')

const email = computed(() => props.document?.supplier_email || 'No email set for supplier')
const subject = computed(
  () => `Purchase Order ${props.document?.doc_number || ''} - Seven Waves Restaurant`,
)

async function onSend() {
  if (!props.document?.id) return
  if (!props.document?.supplier_email) {
    $q.notify({
      type: 'warning',
      message: 'Supplier email is missing. Please update the supplier profile first.',
      icon: 'contact_mail',
    })
    return
  }

  sending.value = true
  try {
    const result = await sendPOEmail(props.document.id, customMessage.value)
    $q.notify({
      type: 'positive',
      message: result.message || 'Email sent successfully to supplier!',
      icon: 'check_circle',
      timeout: 3000,
    })
    emit('sent')
    emit('update:modelValue', false)
  } catch (e) {
    $q.notify({
      type: 'negative',
      message: 'Email service error: ' + (e.message || 'Unknown error'),
      icon: 'error',
    })
  } finally {
    sending.value = false
  }
}
</script>
