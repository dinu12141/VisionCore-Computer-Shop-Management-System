<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    persistent
  >
    <q-card
      :class="$q.dark.isActive ? 'bg-grey-9 text-white' : 'bg-white text-grey-9'"
      style="min-width: 400px; border-radius: 12px"
    >
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">
          <q-icon name="download" color="primary" class="q-mr-sm" />
          Export Document
        </div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md">
        <div class="text-subtitle2 q-mb-md text-grey-5">Choose your preferred file format:</div>

        <div class="column q-gutter-sm">
          <q-btn
            color="red-9"
            icon="picture_as_pdf"
            label="Download as PDF (.pdf)"
            class="full-width"
            align="left"
            @click="onExportPDF"
          />
          <q-btn
            color="green-9"
            icon="description"
            label="Download as Excel (.xlsx)"
            class="full-width"
            align="left"
            @click="onExportExcel"
          />
          <q-btn
            color="blue-9"
            icon="image"
            label="Download as Image (.png)"
            class="full-width"
            align="left"
            @click="onExportPNG"
          />
        </div>

        <!-- Hidden component for PNG rendering -->
        <div style="position: absolute; left: -9999px; top: -9999px">
          <div
            ref="exportContainer"
            style="width: 800px; background: white; padding: 40px; color: black"
          >
            <!-- Simplified print layout here -->
            <div class="row justify-between q-mb-xl">
              <div class="col-8">
                <div style="font-size: 32px; font-weight: 800; color: #1976d2">
                  {{ document.doc_type }} DOCUMENT
                </div>
                <div style="font-size: 18px; color: #666">#{{ document.doc_number }}</div>
              </div>
              <div class="col-4 text-right">
                <div style="font-size: 20px; font-weight: 700">Seven Waves Restaurant</div>
                <div style="font-size: 12px">Galle, Sri Lanka</div>
              </div>
            </div>

            <div class="row q-mb-lg" style="border-top: 2px solid #eee; padding-top: 20px">
              <div class="col-6">
                <div style="font-size: 10px; color: #999; text-transform: uppercase">Warehouse</div>
                <div style="font-size: 14px; font-weight: 600">{{ document.warehouse_name }}</div>

                <div v-if="document.supplier_name" class="q-mt-sm">
                  <div style="font-size: 10px; color: #999; text-transform: uppercase">
                    Supplier
                  </div>
                  <div style="font-size: 14px; font-weight: 600">{{ document.supplier_name }}</div>
                </div>
              </div>
              <div class="col-6 text-right">
                <div style="font-size: 10px; color: #999; text-transform: uppercase">Date</div>
                <div style="font-size: 14px; font-weight: 600">{{ document.doc_date }}</div>
              </div>
            </div>

            <table style="width: 100%; border-collapse: collapse; margin-top: 20px">
              <thead>
                <tr style="background: #f5f5f5; border-bottom: 2px solid #ddd">
                  <th style="padding: 10px; text-align: left">Item</th>
                  <th style="padding: 10px; text-align: right">Qty</th>
                  <th style="padding: 10px; text-align: right">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="l in lines" :key="l.id" style="border-bottom: 1px solid #eee">
                  <td style="padding: 10px">{{ l.item_name }}</td>
                  <td style="padding: 10px; text-align: right">
                    {{ l.quantity }} {{ l.uom_code }}
                  </td>
                  <td style="padding: 10px; text-align: right">
                    {{ (l.quantity * l.unit_cost).toLocaleString() }}
                  </td>
                </tr>
              </tbody>
            </table>

            <div class="text-center q-mt-xl" style="font-size: 10px; color: #ccc">
              Generated via Seven Waves ERP
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref } from 'vue'
import { exportToPDF, exportToExcel } from 'src/services/exportService'
import * as htmlToImage from 'html-to-image'
import { useQuasar } from 'quasar'

const props = defineProps({
  modelValue: Boolean,
  document: Object,
  lines: Array,
})

const emit = defineEmits(['update:modelValue'])
const $q = useQuasar()
const exportContainer = ref(null)

function onExportPDF() {
  try {
    exportToPDF(props.document, props.lines)
    $q.notify({ type: 'positive', message: 'PDF exported successfully' })
    emit('update:modelValue', false)
  } catch (err) {
    console.error('PDF Export Error:', err)
    $q.notify({ type: 'negative', message: 'PDF export failed' })
  }
}

function onExportExcel() {
  try {
    exportToExcel(props.document, props.lines)
    $q.notify({ type: 'positive', message: 'Excel exported successfully' })
    emit('update:modelValue', false)
  } catch (err) {
    console.error('Excel Export Error:', err)
    $q.notify({ type: 'negative', message: 'Excel export failed' })
  }
}

async function onExportPNG() {
  if (!exportContainer.value) return

  $q.loading.show({
    message: 'Generating image...',
  })

  try {
    const dataUrl = await htmlToImage.toPng(exportContainer.value, {
      quality: 1,
      pixelRatio: 2,
    })

    const link = document.createElement('a')
    link.download = `${props.document.doc_type}_${props.document.doc_number}.png`
    link.href = dataUrl
    link.click()

    $q.notify({ type: 'positive', message: 'Image exported successfully' })
    emit('update:modelValue', false)
  } catch (err) {
    console.error('Image Export Error:', err)
    $q.notify({ type: 'negative', message: 'Image export failed' })
  } finally {
    $q.loading.hide()
  }
}
</script>
