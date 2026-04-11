<template>
  <q-page class="q-pa-lg">
    <!-- Loading -->
    <div v-if="store.loading && !store.currentJob" class="flex flex-center q-pa-xl">
      <q-spinner-dots color="primary" size="48px" />
    </div>

    <template v-else-if="job">
      <!-- Header -->
      <div class="row items-start q-mb-lg q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-sm q-mb-xs">
            <q-btn flat dense round icon="arrow_back" @click="$router.push('/services/jobs')" />
            <h1 class="text-h5 text-weight-bolder q-ma-none">{{ job.job_no }}</h1>
            <q-badge
              :color="store.STATUS_COLORS[job.status]"
              :label="store.STATUS_LABELS[job.status]"
              class="text-capitalize q-ml-sm"
              style="font-size: 13px"
            />
            <q-badge
              :color="store.PRIORITY_COLORS[job.priority]"
              :label="job.priority"
              class="text-capitalize"
              outline
            />
          </div>
          <div class="text-grey-6">
            {{ job.brand || '' }} {{ job.model || '' }}
            <span v-if="job.customer" class="q-ml-sm">• {{ job.customer.name }}</span>
          </div>
        </div>
        <div class="col-auto q-gutter-sm">
          <!-- Status Update -->
          <q-btn-dropdown
            color="primary"
            label="Update Status"
            icon="sync"
            v-if="nextStatuses.length"
          >
            <q-list>
              <q-item
                v-for="s in nextStatuses"
                :key="s"
                clickable
                v-close-popup
                @click="changeStatus(s)"
              >
                <q-item-section avatar>
                  <q-badge :color="store.STATUS_COLORS[s]" rounded />
                </q-item-section>
                <q-item-section>{{ store.STATUS_LABELS[s] }}</q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
          <q-btn flat icon="download" label="Download PDF" @click="downloadPdf" color="secondary" />
          <q-btn flat icon="print" label="Report" @click="openReportDialog" color="primary" />
          <q-btn
            flat
            icon="edit"
            label="Edit Job"
            @click="$router.push(`/services/edit/${job.id}`)"
            color="blue"
          />
          <q-btn flat icon="delete" label="Delete" @click="confirmDelete" color="negative" />
          <q-btn
            v-if="job.payment_status !== 'paid'"
            unelevated
            color="primary"
            icon="receipt_long"
            label="Pay → Invoice"
            class="q-ml-sm"
            @click="goToBillingWithJobDetails"
          />
        </div>
      </div>

      <!-- Tabs -->
      <q-card flat bordered class="glass-card">
        <q-tabs
          v-model="activeTab"
          dense
          align="left"
          :dark="$q.dark.isActive"
          narrow-indicator
          class="q-px-md"
        >
          <q-tab name="overview" label="Overview" icon="info" />
          <q-tab
            name="diagnosis"
            label="Diagnosis"
            icon="search"
            :alert="store.diagnosisItems.length > 0 ? 'blue' : false"
          />
          <q-tab
            name="parts"
            label="Parts Used"
            icon="category"
            :alert="store.partsUsed.length > 0 ? 'green' : false"
          />
          <q-tab name="activity" label="Activity" icon="history" />
          <q-tab name="reports" label="Reports" icon="description" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="activeTab" animated :dark="$q.dark.isActive" class="bg-transparent">
          <!-- ─── OVERVIEW TAB ────────────────────── -->
          <q-tab-panel name="overview">
            <div class="row q-col-gutter-lg">
              <!-- Device Info -->
              <div class="col-12 col-md-6">
                <div class="text-subtitle2 text-weight-bold q-mb-sm">Device Information</div>
                <q-list dense separator>
                  <q-item
                    ><q-item-section>Type</q-item-section
                    ><q-item-section side class="text-weight-bold text-capitalize">{{
                      job.device_type
                    }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Brand</q-item-section
                    ><q-item-section side class="text-weight-bold">{{
                      job.brand || '-'
                    }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Model</q-item-section
                    ><q-item-section side class="text-weight-bold">{{
                      job.model || '-'
                    }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Serial #</q-item-section
                    ><q-item-section side class="text-weight-bold">{{
                      job.serial_no || '-'
                    }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Accessories</q-item-section
                    ><q-item-section side>
                      <q-badge
                        v-for="a in job.accessories_received || []"
                        :key="a"
                        :label="a"
                        color="grey-7"
                        class="q-mr-xs q-mb-xs"
                      />
                      <span v-if="!job.accessories_received?.length" class="text-grey">None</span>
                    </q-item-section></q-item
                  >
                </q-list>
              </div>

              <!-- Customer + Dates -->
              <div class="col-12 col-md-6">
                <div class="text-subtitle2 text-weight-bold q-mb-sm">Customer & Schedule</div>
                <q-list dense separator>
                  <q-item
                    ><q-item-section>Customer</q-item-section
                    ><q-item-section side class="text-weight-bold">{{
                      job.customer?.name || 'Walk-in'
                    }}</q-item-section></q-item
                  >
                  <q-item v-if="job.customer?.phone"
                    ><q-item-section>Phone</q-item-section
                    ><q-item-section side>{{ job.customer.phone }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Received</q-item-section
                    ><q-item-section side class="text-weight-bold">{{
                      job.received_date
                    }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>ETA</q-item-section
                    ><q-item-section side :class="isOverdue ? 'text-negative text-weight-bold' : ''"
                      >{{ job.estimated_fix_date || 'Not set' }}
                      {{ isOverdue ? '⚠️ OVERDUE' : '' }}</q-item-section
                    ></q-item
                  >
                  <q-item
                    ><q-item-section>Delivered</q-item-section
                    ><q-item-section side>{{ job.delivered_date || '-' }}</q-item-section></q-item
                  >
                  <q-item
                    ><q-item-section>Warranty</q-item-section
                    ><q-item-section side>{{ job.warranty_days || 0 }} days</q-item-section></q-item
                  >
                </q-list>
              </div>

              <!-- Issue & Notes -->
              <div class="col-12">
                <div class="text-subtitle2 text-weight-bold q-mb-sm">Issue Reported</div>
                <q-card flat bordered class="q-pa-md" :dark="$q.dark.isActive">
                  {{ job.issue_reported_by_customer || 'No issue description' }}
                </q-card>
              </div>
              <div class="col-12" v-if="job.inspection_notes">
                <div class="text-subtitle2 text-weight-bold q-mb-sm">Inspection Notes</div>
                <q-card flat bordered class="q-pa-md" :dark="$q.dark.isActive">
                  {{ job.inspection_notes }}
                </q-card>
              </div>
            </div>
          </q-tab-panel>

          <!-- ─── DIAGNOSIS TAB ──────────────────── -->
          <q-tab-panel name="diagnosis">
            <div class="row items-center q-mb-md">
              <div class="text-subtitle1 text-weight-bold">Diagnosed Issues</div>
              <q-space />
              <q-btn
                color="primary"
                icon="add"
                label="Add Issue"
                size="sm"
                @click="showDiagDialog = true"
              />
            </div>

            <q-table
              :rows="store.diagnosisItems"
              :columns="diagColumns"
              row-key="id"
              flat
              class="bg-transparent"
              :dark="$q.dark.isActive"
              hide-pagination
              :pagination="{ rowsPerPage: 0 }"
            >
              <template v-slot:body-cell-severity="props">
                <q-td :props="props">
                  <q-badge
                    :color="
                      props.row.severity === 'high'
                        ? 'red'
                        : props.row.severity === 'medium'
                          ? 'orange'
                          : 'grey'
                    "
                    :label="props.row.severity"
                    class="text-capitalize"
                  />
                </q-td>
              </template>
              <template v-slot:body-cell-is_fixed="props">
                <q-td :props="props">
                  <q-icon
                    :name="props.row.is_fixed ? 'check_circle' : 'cancel'"
                    :color="props.row.is_fixed ? 'positive' : 'grey'"
                    size="20px"
                  />
                </q-td>
              </template>
              <template v-slot:body-cell-actions="props">
                <q-td :props="props">
                  <q-btn
                    flat
                    round
                    dense
                    icon="check"
                    color="positive"
                    size="sm"
                    v-if="!props.row.is_fixed"
                    @click="markFixed(props.row)"
                  >
                    <q-tooltip>Mark Fixed</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    dense
                    icon="delete"
                    color="negative"
                    size="sm"
                    @click="removeDiag(props.row.id)"
                  >
                    <q-tooltip>Delete</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
              <template v-slot:no-data>
                <div class="full-width text-center q-pa-lg text-grey-5">
                  <q-icon name="search_off" size="40px" /><br />No diagnosis items yet
                </div>
              </template>
            </q-table>

            <!-- Add Diagnosis Dialog -->
            <q-dialog v-model="showDiagDialog" persistent>
              <q-card style="min-width: 500px" :dark="$q.dark.isActive">
                <q-card-section class="row items-center">
                  <div class="text-h6">Add Diagnosis Item</div>
                  <q-space /><q-btn icon="close" flat round dense v-close-popup />
                </q-card-section>
                <q-separator />
                <q-card-section class="q-gutter-md">
                  <q-select
                    v-model="diagForm.category"
                    label="Category"
                    :options="categoryOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    :dark="$q.dark.isActive"
                  />
                  <q-input
                    v-model="diagForm.error_title"
                    label="Error Title *"
                    outlined
                    dense
                    :dark="$q.dark.isActive"
                  />
                  <q-input
                    v-model="diagForm.error_description"
                    label="Description"
                    type="textarea"
                    rows="2"
                    outlined
                    dense
                    :dark="$q.dark.isActive"
                  />
                  <q-select
                    v-model="diagForm.severity"
                    label="Severity"
                    :options="severityOptions"
                    emit-value
                    map-options
                    outlined
                    dense
                    :dark="$q.dark.isActive"
                  />
                  <q-input
                    v-model="diagForm.recommended_fix"
                    label="Recommended Fix"
                    outlined
                    dense
                    :dark="$q.dark.isActive"
                  />
                </q-card-section>
                <q-card-actions align="right" class="q-pa-md">
                  <q-btn flat label="Cancel" v-close-popup />
                  <q-btn
                    color="primary"
                    label="Add"
                    icon="add"
                    @click="addDiagItem"
                    :loading="store.loading"
                  />
                </q-card-actions>
              </q-card>
            </q-dialog>
          </q-tab-panel>

          <!-- ─── PARTS USED TAB ─────────────────── -->
          <q-tab-panel name="parts">
            <div class="row items-center q-mb-md">
              <div class="text-subtitle1 text-weight-bold">Parts Used</div>
              <q-space />
              <q-btn
                color="primary"
                icon="add"
                label="Add Part"
                size="sm"
                @click="showPartDialog = true"
              />
            </div>

            <q-table
              :rows="store.partsUsed"
              :columns="partColumns"
              row-key="id"
              flat
              class="bg-transparent"
              :dark="$q.dark.isActive"
              hide-pagination
              :pagination="{ rowsPerPage: 0 }"
            >
              <template v-slot:body-cell-actions="props">
                <q-td :props="props">
                  <q-btn
                    flat
                    round
                    dense
                    icon="delete"
                    color="negative"
                    size="sm"
                    @click="removePart(props.row.id)"
                  />
                </q-td>
              </template>
              <template v-slot:no-data>
                <div class="full-width text-center q-pa-lg text-grey-5">
                  <q-icon name="category" size="40px" /><br />No parts used yet
                </div>
              </template>
            </q-table>

            <!-- Add Part Dialog -->
            <q-dialog v-model="showPartDialog" persistent>
              <q-card style="min-width: 450px" :dark="$q.dark.isActive">
                <q-card-section class="row items-center">
                  <div class="text-h6">Add Part</div>
                  <q-space /><q-btn icon="close" flat round dense v-close-popup />
                </q-card-section>
                <q-separator />
                <q-card-section>
                  <div class="row q-col-gutter-md">
                    <div class="col-12">
                      <!-- Inventory item selector with manual fallback -->
                      <q-select
                        v-if="!useManualItemName"
                        v-model="partForm.selectedItem"
                        label="Part / Item Name *"
                        :options="filteredInventoryItems"
                        option-value="id"
                        option-label="name"
                        emit-value
                        map-options
                        outlined
                        dense
                        use-input
                        clearable
                        :dark="$q.dark.isActive"
                        @filter="filterInventoryItems"
                        @update:model-value="onInventoryItemSelected"
                      >
                        <template v-slot:option="scope">
                          <q-item v-bind="scope.itemProps">
                            <q-item-section>
                              <q-item-label>{{ scope.opt.name }}</q-item-label>
                              <q-item-label caption>
                                {{ scope.opt.code }}
                                · LKR {{ (scope.opt.sale_price > 0 ? scope.opt.sale_price : scope.opt.avg_cost > 0 ? scope.opt.avg_cost : scope.opt.last_purchase_price || 0).toLocaleString('en', { minimumFractionDigits: 2 }) }}
                              </q-item-label>
                            </q-item-section>
                          </q-item>
                        </template>
                        <template v-slot:no-option="{ inputValue }">
                          <q-item clickable @click="switchToManual(inputValue)">
                            <q-item-section class="text-primary text-weight-bold">
                              <span>+ Add "{{ inputValue }}" as custom item</span>
                            </q-item-section>
                          </q-item>
                        </template>
                        <template v-slot:after>
                          <q-btn
                            flat
                            round
                            icon="edit"
                            color="primary"
                            dense
                            @click="switchToManual('')"
                          >
                            <q-tooltip>Type custom item name</q-tooltip>
                          </q-btn>
                        </template>
                      </q-select>

                      <!-- Manual text input fallback -->
                      <q-input
                        v-else
                        v-model="partForm.item_name"
                        label="Part / Item Name *"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                        autofocus
                      >
                        <template v-slot:after>
                          <q-btn
                            flat
                            round
                            icon="list"
                            color="primary"
                            dense
                            @click="switchToSelector"
                          >
                            <q-tooltip>Pick from inventory</q-tooltip>
                          </q-btn>
                        </template>
                      </q-input>
                    </div>
                    <div class="col-12 col-sm-3">
                      <q-input
                        v-model.number="partForm.qty"
                        label="Qty"
                        type="number"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                      />
                    </div>
                    <div class="col-12 col-sm-4">
                      <q-input
                        v-model.number="partForm.unit_price"
                        label="Unit Price (LKR)"
                        type="number"
                        outlined
                        dense
                        prefix="LKR"
                        :dark="$q.dark.isActive"
                        hint="Auto-filled from inventory"
                      />
                    </div>
                    <div class="col-12">
                      <q-input
                        v-model="partForm.notes"
                        label="Serial N.o / Notes"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                      />
                    </div>
                  </div>
                </q-card-section>
                <q-card-actions align="right" class="q-pa-md">
                  <q-btn flat label="Cancel" v-close-popup />
                  <q-btn
                    color="primary"
                    label="Add"
                    icon="add"
                    @click="addPartItem"
                    :loading="store.loading"
                  />
                </q-card-actions>
              </q-card>
            </q-dialog>
          </q-tab-panel>

          <!-- ─── ACTIVITY TAB ───────────────────── -->
          <q-tab-panel name="activity">
            <div class="text-subtitle1 text-weight-bold q-mb-md">Activity Timeline</div>
            <q-timeline v-if="store.activityLog.length" color="primary" layout="comfortable">
              <q-timeline-entry
                v-for="log in store.activityLog"
                :key="log.id"
                :title="log.description"
                :subtitle="formatDate(log.created_at)"
                :icon="activityIcon(log.action)"
                :color="activityColor(log.action)"
              />
            </q-timeline>
            <div v-else class="text-center text-grey q-pa-xl">
              <q-icon name="history" size="48px" /><br />No activity yet
            </div>
          </q-tab-panel>

          <!-- ─── REPORTS TAB ────────────────────── -->
          <q-tab-panel name="reports">
            <div class="row items-center q-mb-md">
              <div class="text-subtitle1 text-weight-bold">Service Reports</div>
              <q-space />
              <q-btn
                color="primary"
                icon="note_add"
                label="Generate Report"
                size="sm"
                @click="openReportDialog"
              />
            </div>

            <q-list separator v-if="store.reports.length">
              <q-item v-for="rpt in store.reports" :key="rpt.id" class="q-py-md">
                <q-item-section avatar>
                  <q-avatar color="primary" text-color="white" icon="description" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-weight-bold">{{ rpt.report_no }}</q-item-label>
                  <q-item-label caption>
                    {{
                      rpt.report_type === 'inspection'
                        ? 'Inspection Report'
                        : rpt.report_type === 'final'
                          ? 'Completion Report'
                          : 'Other Report'
                    }}
                    • {{ formatDate(rpt.generated_at) }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side class="q-gutter-xs">
                  <q-btn flat round icon="edit" color="blue" @click="editReport(rpt)" size="sm">
                    <q-tooltip>Edit Report Notes</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    icon="delete"
                    color="negative"
                    @click="deleteReport(rpt)"
                    size="sm"
                  >
                    <q-tooltip>Delete Report</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    icon="visibility"
                    color="teal"
                    @click="printReport(rpt, false)"
                    size="sm"
                  >
                    <q-tooltip>View Report</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    round
                    icon="print"
                    color="primary"
                    @click="printReport(rpt)"
                    size="sm"
                  >
                    <q-tooltip>Print / Download</q-tooltip>
                  </q-btn>
                </q-item-section>
              </q-item>
            </q-list>
            <div v-else class="text-center text-grey q-pa-xl">
              <q-icon name="description" size="48px" /><br />No reports generated
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-card>
    </template>

    <!-- Report Generation Dialog -->
    <q-dialog v-model="showReportDialog" persistent>
      <q-card style="min-width: 500px" :dark="$q.dark.isActive">
        <q-card-section class="row items-center">
          <div class="text-h6">{{ editingReportId ? 'Edit' : 'Generate' }} Service Report</div>
          <q-space /><q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-gutter-md scroll" style="max-height: 70vh">
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="reportForm.type"
                label="Report Type"
                :options="[
                  { label: 'Inspection Report', value: 'inspection' },
                  { label: 'Completion Report', value: 'final' },
                  { label: 'Other', value: 'other' },
                ]"
                emit-value
                map-options
                outlined
                dense
                :dark="$q.dark.isActive"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-input v-model="reportForm.customerName" label="Customer Name" outlined dense />
            </div>
          </div>

          <q-expansion-item
            label="Device & Issue Details"
            icon="laptop"
            header-class="text-primary text-weight-bold"
            dense
            bordered
            class="overflow-hidden border-radius-8"
          >
            <q-card>
              <q-card-section class="q-gutter-sm">
                <div class="row q-col-gutter-sm">
                  <div class="col-6">
                    <q-input v-model="reportForm.deviceType" label="Device Type" outlined dense />
                  </div>
                  <div class="col-6">
                    <q-input v-model="reportForm.brand" label="Brand" outlined dense />
                  </div>
                  <div class="col-6">
                    <q-input v-model="reportForm.model" label="Model" outlined dense />
                  </div>
                  <div class="col-6">
                    <q-input v-model="reportForm.serialNo" label="Serial No" outlined dense />
                  </div>
                </div>
                <q-input
                  v-model="reportForm.issueReported"
                  label="Reported Issue"
                  type="textarea"
                  outlined
                  dense
                  autogrow
                />
                <q-input
                  v-model="reportForm.inspectionNotes"
                  label="Inspection Notes"
                  type="textarea"
                  outlined
                  dense
                  autogrow
                />
              </q-card-section>
            </q-card>
          </q-expansion-item>

          <q-input
            v-model="reportForm.summary"
            label="Executive Summary / Final Notes"
            type="textarea"
            outlined
            dense
            autogrow
            placeholder="Enter professional summary of current work..."
          />
          <div class="text-subtitle2 q-mt-sm">Included Sections</div>
          <div class="q-gutter-sm row">
            <q-toggle
              v-model="reportForm.includeDevice"
              label="Device Details"
              dense
              color="primary"
            />
            <q-toggle
              v-model="reportForm.includeDiagnosis"
              label="Diagnosis Items"
              dense
              color="primary"
            />
            <q-toggle v-model="reportForm.includeParts" label="Parts Used" dense color="primary" />
            <q-toggle
              v-model="reportForm.includeWarranty"
              label="Warranty Statement"
              dense
              color="primary"
            />
          </div>
        </q-card-section>
        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            label="Generate & Print"
            icon="print"
            @click="generateReport"
            :loading="generatingReport"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useServiceStore } from 'src/stores/serviceStore'
import { useAuthStore } from 'src/stores/auth'
import { supabase } from 'src/boot/supabase'
import { downloadServiceJobPDF } from 'src/services/serviceReportPdf'

const $q = useQuasar()
const route = useRoute()
const router = useRouter()
const store = useServiceStore()
const authStore = useAuthStore()

// ── Inventory items for Part picker ──────────────────────────────
const inventoryItems = ref([])
const filteredInventoryItems = ref([])
const useManualItemName = ref(false)

async function loadInventoryItems() {
  const companyId = authStore.currentBranch?.company_id
  if (!companyId) return
  const { data } = await supabase
    .from('items')
    .select('id, name, code, sale_price, avg_cost, last_purchase_price')
    .eq('company_id', companyId)
    .eq('is_active', true)
    .order('name')
    .limit(500)
  inventoryItems.value = data || []
  filteredInventoryItems.value = data || []
}

function filterInventoryItems(val, update) {
  update(() => {
    const q = (val || '').toLowerCase()
    filteredInventoryItems.value = q
      ? inventoryItems.value.filter(
          (i) => i.name.toLowerCase().includes(q) || (i.code || '').toLowerCase().includes(q),
        )
      : inventoryItems.value
  })
}

function onInventoryItemSelected(itemId) {
  if (!itemId) {
    partForm.item_name = ''
    partForm.unit_price = 0
    return
  }
  const item = inventoryItems.value.find((i) => i.id === itemId)
  if (item) {
    partForm.item_name = item.name
    // Best available price: sale_price → avg_cost → last_purchase_price
    partForm.unit_price = Number(
      item.sale_price > 0 ? item.sale_price
      : item.avg_cost > 0 ? item.avg_cost
      : item.last_purchase_price > 0 ? item.last_purchase_price
      : 0
    )
  }
}

function switchToManual(prefill = '') {
  useManualItemName.value = true
  partForm.item_name = prefill
  partForm.selectedItem = null
}

function switchToSelector() {
  useManualItemName.value = false
  partForm.item_name = ''
  partForm.selectedItem = null
  partForm.unit_price = 0
}

async function downloadPdf() {
  if (!job.value?.id) return
  $q.loading.show({ message: 'Generating PDF...' })
  try {
    await downloadServiceJobPDF(job.value.id)
    $q.notify({ type: 'positive', message: 'Report downloaded successfully' })
  } catch (err) {
    console.error(err)
    $q.notify({ type: 'negative', message: 'Failed to generate PDF: ' + err.message })
  } finally {
    $q.loading.hide()
  }
}

function confirmDelete() {
  if (!job.value) return
  $q.dialog({
    title: 'Confirm Delete',
    message: `Are you sure you want to delete service job ${job.value.job_no}? This cannot be undone.`,
    cancel: true,
    persistent: true,
    ok: {
      flat: true,
      color: 'negative',
      label: 'Delete',
    },
  }).onOk(async () => {
    $q.loading.show({ message: 'Deleting job...' })
    try {
      await store.deleteJob(job.value.id)
      $q.notify({ type: 'positive', message: 'Job deleted successfully' })
      router.push('/services/jobs')
    } catch (err) {
      $q.notify({ type: 'negative', message: 'Failed to delete: ' + err.message })
    } finally {
      $q.loading.hide()
    }
  })
}

const activeTab = ref('overview')
const showDiagDialog = ref(false)
const showPartDialog = ref(false)
const showReportDialog = ref(false)
const generatingReport = ref(false)
const editingReportId = ref(null)

const job = computed(() => store.currentJob)

const isOverdue = computed(() => {
  if (!job.value?.estimated_fix_date) return false
  if (['delivered', 'closed', 'cancelled'].includes(job.value.status)) return false
  return new Date(job.value.estimated_fix_date) < new Date()
})

const nextStatuses = computed(() => {
  if (!job.value) return []
  return store.STATUS_FLOW[job.value.status] || []
})

// Diagnosis form
const diagForm = reactive({
  category: 'hardware',
  error_title: '',
  error_description: '',
  severity: 'medium',
  recommended_fix: '',
})

const categoryOptions = [
  { label: 'Hardware', value: 'hardware' },
  { label: 'Software', value: 'software' },
  { label: 'Power', value: 'power' },
  { label: 'Display', value: 'display' },
  { label: 'Network', value: 'network' },
  { label: 'Storage', value: 'storage' },
  { label: 'Other', value: 'other' },
]

const severityOptions = [
  { label: 'Low', value: 'low' },
  { label: 'Medium', value: 'medium' },
  { label: 'High', value: 'high' },
]

const diagColumns = [
  { name: 'category', label: 'Category', field: 'category', align: 'left', sortable: true },
  { name: 'error_title', label: 'Issue', field: 'error_title', align: 'left' },
  { name: 'severity', label: 'Severity', field: 'severity', align: 'center' },
  { name: 'recommended_fix', label: 'Fix', field: 'recommended_fix', align: 'left' },
  { name: 'is_fixed', label: 'Fixed', field: 'is_fixed', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

// Parts form
const partForm = reactive({
  selectedItem: null, // inventory item id
  item_name: '',
  qty: 1,
  unit_price: 0,
  notes: '',
})

const partColumns = [
  { name: 'item_name', label: 'Item', field: 'item_name', align: 'left' },
  { name: 'qty', label: 'Qty', field: 'qty', align: 'center' },
  {
    name: 'unit_price',
    label: 'Unit Price',
    field: 'unit_price',
    align: 'right',
    format: (v) => v > 0 ? 'LKR ' + Number(v).toLocaleString('en', { minimumFractionDigits: 2 }) : '—',
  },
  {
    name: 'total',
    label: 'Total',
    field: 'total',
    align: 'right',
    format: (v) => v > 0 ? 'LKR ' + Number(v).toLocaleString('en', { minimumFractionDigits: 2 }) : '—',
  },
  { name: 'notes', label: 'SN / Notes', field: 'notes', align: 'left' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

// Report form
const reportForm = reactive({
  type: 'inspection',
  summary: '',
  customerName: '',
  deviceType: '',
  brand: '',
  model: '',
  serialNo: '',
  issueReported: '',
  inspectionNotes: '',
  includeDevice: true,
  includeDiagnosis: true,
  includeParts: true,
  includeCosts: true,
  includeWarranty: true,
})

// Actions
async function changeStatus(newStatus) {
  $q.dialog({
    title: 'Confirm Status Change',
    message: `Change status to <b>${store.STATUS_LABELS[newStatus]}</b>?`,
    html: true,
    cancel: true,
    persistent: true,
    dark: $q.dark.isActive,
    ok: { label: 'Confirm', color: 'primary' },
  }).onOk(async () => {
    try {
      await store.updateStatus(job.value.id, newStatus)
      await store.fetchJob(job.value.id)
      $q.notify({
        type: 'positive',
        message: `Status updated to ${store.STATUS_LABELS[newStatus]}`,
      })
    } catch (err) {
      $q.notify({ type: 'negative', message: err.message })
    }
  })
}

// Navigate to billing and pre-fill items (Repairs + Parts)
function goToBillingWithJobDetails() {
  const j = job.value
  if (!j) return

  // Final cost (Labor/Service)
  const servicePrice =
    Number(j.total_final_cost || 0) > 0
      ? Number(j.total_final_cost)
      : Number(j.total_estimated_cost || 0)

  // Build items: 1. Reported Issue (Service Line), 2. Parts Used
  const lineItems = []

  // Add Reported Issue as the main service line
  lineItems.push({
    description: j.issue_reported_by_customer
      ? `Repair: ${j.issue_reported_by_customer} (${j.brand || ''} ${j.model || ''})`
      : `Service Charge: ${j.job_no} (${j.brand || ''} ${j.model || ''})`,
    qty: 1,
    unit_price: servicePrice,
    line_total: servicePrice,
    item_code: 'SERVICE',
    is_service: true,
  })

  // Add Parts used as separate lines
  // NOTE: stock is already deducted when parts are added to the service job.
  // We pass item_code for reference but NOT product_id to avoid double-deduction
  // by the invoice stock trigger.
  const partLines = (store.partsUsed || []).map((p) => {
    // If price was saved as 0 (old records before the fix), fall back to item's current price
    const storedPrice = Number(p.unit_price || 0)
    const itemFallbackPrice = storedPrice === 0
      ? Number(
          p.item?.sale_price > 0 ? p.item.sale_price
          : p.item?.avg_cost > 0 ? p.item.avg_cost
          : p.item?.last_purchase_price > 0 ? p.item.last_purchase_price
          : 0
        )
      : storedPrice
    const qty = Number(p.qty || 1)
    const lineTotal = Number(p.total || 0) > 0
      ? Number(p.total)
      : qty * itemFallbackPrice

    return {
      description: p.item_name,
      qty,
      unit_price: itemFallbackPrice,
      discount: 0,
      line_total: lineTotal,
      warranty: '',
      serial_number: p.notes || '',
      item_code: p.item?.code || '',
      product_id: p.item_id || p.item?.id || null, // Let invoice GIN deduct the exact items billed
    }
  })

  lineItems.push(...partLines)

  const prefill = {
    source: 'service_job',
    job_id: j.id,
    job_no: j.job_no,
    is_service_invoice: true,
    // Customer details
    customer_id: j.customer_id || null,
    customer_name: j.customer?.name || null,
    customer_phone: j.customer?.phone || null,
    // Combined items
    items: lineItems,
  }

  sessionStorage.setItem('billing_prefill', JSON.stringify(prefill))
  router.push('/billing')
}

async function addDiagItem() {
  if (!diagForm.error_title) {
    $q.notify({ type: 'warning', message: 'Error title is required' })
    return
  }
  try {
    await store.addDiagnosis(job.value.id, { ...diagForm })
    showDiagDialog.value = false
    Object.assign(diagForm, {
      category: 'hardware',
      error_title: '',
      error_description: '',
      severity: 'medium',
      recommended_fix: '',
    })
    $q.notify({ type: 'positive', message: 'Diagnosis item added' })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function markFixed(item) {
  try {
    await store.updateDiagnosis(item.id, { is_fixed: true, fixed_notes: 'Resolved' })
    $q.notify({ type: 'positive', message: 'Marked as fixed' })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function removeDiag(id) {
  try {
    await store.deleteDiagnosis(id)
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function addPartItem() {
  const name = partForm.item_name || ''
  if (!name.trim()) {
    $q.notify({ type: 'warning', message: 'Part name is required' })
    return
  }
  try {
    await store.addPart(job.value.id, {
      item_id: partForm.selectedItem || null,
      item_name: name.trim(),
      qty: partForm.qty,
      unit_price: partForm.unit_price,
      notes: partForm.notes,
    })

    // ── NOTE: Stock deduction logic was removed from here. 
    // It is now handled exactly by the invoice when the service job is billed.

    showPartDialog.value = false
    Object.assign(partForm, { selectedItem: null, item_name: '', qty: 1, unit_price: 0, notes: '' })
    useManualItemName.value = false
    $q.notify({ type: 'positive', message: 'Part added successfully' })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function removePart(id) {
  try {
    // Find the part before deleting so we can restore stock (logic removed, now tied to invoices)
    await store.deletePart(id)

    // ── NOTE: Stock restore logic removed. Stock is now strictly tied to invoices.
    $q.notify({ type: 'positive', message: 'Part removed' })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

function openReportDialog() {
  editingReportId.value = null
  Object.assign(reportForm, {
    type: 'inspection',
    summary: '',
    customerName: job.value.customer?.name || 'Walk-in',
    deviceType: job.value.device_type || '',
    brand: job.value.brand || '',
    model: job.value.model || '',
    serialNo: job.value.serial_no || '',
    issueReported: job.value.issue_reported_by_customer || '',
    inspectionNotes: job.value.inspection_notes || '',
    includeDevice: true,
    includeDiagnosis: true,
    includeParts: true,
    includeCosts: true,
    includeWarranty: true,
  })
  showReportDialog.value = true
}

function editReport(rpt) {
  editingReportId.value = rpt.id
  const content = rpt.content_json || {}
  const j = content.job || {}
  Object.assign(reportForm, {
    type: rpt.report_type,
    summary: content.summary || '',
    customerName: j.customer?.name || 'Walk-in',
    deviceType: j.device_type || '',
    brand: j.brand || '',
    model: j.model || '',
    serialNo: j.serial_no || '',
    issueReported: j.issue_reported_by_customer || '',
    inspectionNotes: j.inspection_notes || '',
    includeDevice: content.sections?.device !== false,
    includeDiagnosis: content.sections?.diagnosis !== false,
    includeParts: content.sections?.parts !== false,
    includeCosts: content.sections?.costs !== false,
    includeWarranty: content.sections?.warranty !== false,
  })
  showReportDialog.value = true
}

function deleteReport(rpt) {
  $q.dialog({
    title: 'Delete Report',
    message: `Are you sure you want to delete report <b>${rpt.report_no}</b>?`,
    html: true,
    cancel: true,
    persistent: true,
    ok: { label: 'Delete', color: 'negative', flat: true },
  }).onOk(async () => {
    try {
      await store.deleteReport(rpt.id)
      $q.notify({ type: 'positive', message: 'Report deleted' })
    } catch {
      $q.notify({ type: 'negative', message: 'Failed to delete report' })
    }
  })
}

async function generateReport() {
  generatingReport.value = true
  try {
    const content = {
      report_type: reportForm.type,
      summary: reportForm.summary,
      job: {
        ...job.value,
        customer: { ...(job.value.customer || {}), name: reportForm.customerName },
        device_type: reportForm.deviceType,
        brand: reportForm.brand,
        model: reportForm.model,
        serial_no: reportForm.serialNo,
        issue_reported_by_customer: reportForm.issueReported,
        inspection_notes: reportForm.inspectionNotes,
      },
      diagnosis: reportForm.includeDiagnosis ? [...store.diagnosisItems] : [],
      parts: reportForm.includeParts ? [...store.partsUsed] : [],
      sections: {
        device: reportForm.includeDevice,
        diagnosis: reportForm.includeDiagnosis,
        parts: reportForm.includeParts,
        costs: reportForm.includeCosts,
        warranty: reportForm.includeWarranty,
      },
    }

    if (editingReportId.value) {
      await store.updateReport(editingReportId.value, {
        report_type: reportForm.type,
        content_json: content,
      })
      $q.notify({ type: 'positive', message: 'Report updated' })
    } else {
      const report = await store.createReport(job.value.id, reportForm.type, content)
      $q.notify({ type: 'positive', message: 'Report generated' })
      // Auto print after creation
      await printReport(report)
    }
    showReportDialog.value = false
  } catch {
    $q.notify({
      type: 'negative',
      message: (editingReportId.value ? 'Failed to update' : 'Failed to generate') + ' report',
    })
  } finally {
    generatingReport.value = false
  }
}

async function printReport(report, autoPrint = true) {
  const content = report.content_json || {}
  const j = content.job || job.value || {}
  const diag = content.diagnosis || []
  const parts = content.parts || []
  const sections = content.sections || {}

  // ── Convert logo to base64 so it renders in a blank window.open() ──
  // This uses an Image + Canvas approach for better compatibility than direct fetch
  const getLogoDataUrl = async () => {
    const paths = ['/logo.jpg', '/logo.png']
    for (const path of paths) {
      try {
        const url = window.location.origin + path
        const img = new Image()
        img.crossOrigin = 'anonymous'
        const loaded = new Promise((resolve, reject) => {
          img.onload = () => resolve(img)
          img.onerror = () => reject()
        })
        img.src = url
        await loaded
        
        // Convert to base64 via canvas
        const canvas = document.createElement('canvas')
        canvas.width = img.width
        canvas.height = img.height
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0)
        return canvas.toDataURL('image/jpeg')
      } catch {
        // Try next path
      }
    }
    return ''
  }

  const logoDataUrl = await getLogoDataUrl()
  const logoHtml = logoDataUrl
    ? `<img src="${logoDataUrl}" alt="Vision Computers Logo">`
    : ''

  const title =
    report.report_type === 'inspection'
      ? 'Service Inspection Report'
      : report.report_type === 'final'
        ? 'Service Completion Report'
        : 'Service Report'

  let html = `
    <html><head><title> </title>
    <style>
      @page { margin: 12mm 15mm; }
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: 'Segoe UI', sans-serif; padding: 0; color: #1a1a2e; }
      .header { display: flex; align-items: center; justify-content: space-between; border-bottom: 3px solid #4f46e5; padding-bottom: 20px; margin-bottom: 30px; }
      .header .org-info { text-align: left; }
      .header .org-info h1 { font-size: 24px; color: #4f46e5; }
      .header .org-info h2 { font-size: 16px; margin-top: 4px; color: #555; }
      .header .logo img { max-height: 80px; }
      .report-meta { display: flex; justify-content: space-between; margin-bottom: 24px; font-size: 13px; }
      .section { margin-bottom: 15px; page-break-inside: avoid; }
      .section-title { font-size: 14px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: #4f46e5; border-bottom: 1px solid #e0e0e0; padding-bottom: 6px; margin-bottom: 12px; }
      table { width: 100%; border-collapse: collapse; font-size: 13px; }
      th, td { border: 1px solid #ddd; padding: 8px 10px; text-align: left; }
      th { background: #f8f9fa; font-weight: 600; }
      .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 13px; }
      .info-row { display: flex; }
      .info-label { width: 140px; font-weight: 600; color: #555; }
      .warranty { background: #fff3e0; border: 1px solid #ffe0b2; border-radius: 8px; padding: 12px; margin-top: 20px; }
      .signatures { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; margin-top: 100px; }
      .sig-box { border-top: 1px solid #333; padding-top: 8px; text-align: center; font-size: 12px; }
      .footer { text-align: center; margin-top: 40px; font-size: 11px; color: #999; border-top: 1px solid #eee; padding-top: 12px; }
      @media print {
        body { font-size: 11px; color: #000; }
        .header { margin-bottom: 10px; padding-bottom: 5px; border-bottom-width: 2px; }
        .header .logo img { max-height: 50px; }
        .header .org-info h1 { font-size: 18px; }
        .header .org-info h2 { font-size: 14px; }
        .report-meta, .section { margin-bottom: 10px; }
        h1, h2, .section-title { margin-bottom: 8px; font-size: 12px; }
        th, td { padding: 4px; font-size: 11px; }
        .costs-grid { gap: 8px; }
        .cost-box { padding: 8px; }
        .cost-box .value { font-size: 14px; }
        .warranty { margin-top: 10px; padding: 8px; font-size: 11px; }
        .signatures { margin-top: 25px; grid-template-columns: 1fr 1fr; gap: 20px; }
        .footer { margin-top: 15px; font-size: 9px; padding-top: 5px; }
      }
    </style></head><body>
    <div class="header">
      <div class="org-info">
        <h1>VISION COMPUTERS</h1>
        <h2>${title}</h2>
      </div>
      <div class="logo">
        ${logoHtml}
      </div>
    </div>
    <div class="report-meta">
      <div><strong>Report #:</strong> ${report.report_no}</div>
      <div><strong>Job #:</strong> ${j.job_no || '-'}</div>
      <div><strong>Date:</strong> ${new Date(report.generated_at).toLocaleDateString()}</div>
    </div>`

  // Customer
  html += `
    <div class="section">
      <div class="section-title">Customer Details</div>
      <div class="info-grid">
        <div class="info-row"><span class="info-label">Name:</span> ${j.customer?.name || 'Walk-in'}</div>
        <div class="info-row"><span class="info-label">Phone:</span> ${j.customer?.phone || '-'}</div>
        <div class="info-row"><span class="info-label">Email:</span> ${j.customer?.email || '-'}</div>
        <div class="info-row"><span class="info-label">Code:</span> ${j.customer?.customer_code || '-'}</div>
      </div>
    </div>`

  // Device
  if (sections.device !== false) {
    let etaLabel = 'ETA'
    // The instruction "change 'Delivered' row to 'ETA' handling" implies always using 'ETA'
    // if (['delivered', 'closed', 'completed'].includes(j.status?.toLowerCase())) {
    //   etaLabel = 'Delivered'
    // }

    html += `
      <div class="section">
        <div class="section-title">Device Information</div>
        <div class="info-grid">
          <div class="info-row"><span class="info-label">Type:</span> ${j.device_type || '-'}</div>
          <div class="info-row"><span class="info-label">Brand:</span> ${j.brand || '-'}</div>
          <div class="info-row"><span class="info-label">Model:</span> ${j.model || '-'}</div>
          <div class="info-row"><span class="info-label">Serial #:</span> ${j.serial_no || '-'}</div>
          <div class="info-row"><span class="info-label">Received:</span> ${j.received_date || '-'}</div>
          <div class="info-row"><span class="info-label">${etaLabel}:</span> ${j.estimated_fix_date || '-'}</div>
          <div class="info-row"><span class="info-label">Accessories:</span> ${(j.accessories_received || []).join(', ') || 'None'}</div>
        </div>
      </div>`
  }

  // Issue & Inspection Notes
  html += `
    <div class="section">
      <div class="section-title">Issue & Inspection</div>
      <div style="font-size:13px; margin-bottom: 8px;"><strong>Reported Issue:</strong> ${j.issue_reported_by_customer || 'N/A'}</div>
      <div style="font-size:13px;"><strong>Inspection Notes:</strong> ${j.inspection_notes || 'N/A'}</div>
    </div>`

  // Diagnosis
  if (sections.diagnosis !== false && diag.length) {
    html += `
      <div class="section">
        <div class="section-title">Diagnosed Issues</div>
        <table>
          <tr><th>Category</th><th>Issue</th><th>Severity</th><th>Fix</th><th>Fixed</th></tr>
          ${diag
            .map(
              (d) => `<tr>
            <td>${d.category || '-'}</td><td>${d.error_title}</td><td>${d.severity}</td>
            <td>${d.recommended_fix || '-'}</td><td>${d.is_fixed ? '✅' : '❌'}</td>
          </tr>`,
            )
            .join('')}
        </table>
      </div>`
  }

  // Parts
  if (sections.parts !== false && parts.length) {
    html += `
      <div class="section">
        <div class="section-title">Parts Used</div>
        <table>
          <tr><th>Item</th><th>Qty</th><th>SN / Notes</th></tr>
          ${parts
            .map(
              (p) => `<tr>
            <td>${p.item_name || '-'}</td><td>${p.qty}</td>
            <td>${p.notes || '-'}</td>
          </tr>`,
            )
            .join('')}
        </table>
      </div>`
  }

  // Warranty
  if (sections.warranty !== false && j.warranty_days) {
    html += `
      <div class="warranty">
        <strong>⚠️ Warranty Notice:</strong> This repair comes with a <strong>${j.warranty_days} day</strong> warranty from the date of delivery.
        Warranty covers the same issue repaired under this service job. Physical damage, water damage, and misuse are excluded.
      </div>`
  }

  // Summary
  if (content.summary) {
    html += `<div class="section" style="margin-top:20px"><div class="section-title">Additional Notes</div><p style="font-size:13px">${content.summary}</p></div>`
  }

  // Signatures
  html += `
    <div style="flex-grow: 1; min-height: 50px;"></div>
    <div class="signatures">
      <div><div class="sig-box">Technician Signature</div></div>
      <div><div class="sig-box">Customer Signature</div></div>
    </div>
    </body></html>`

  const printWindow = window.open('', '_blank')
  printWindow.document.write(html)
  printWindow.document.close()
  if (autoPrint) {
    // Small delay to ensure base64 image is ready for print preview
    setTimeout(() => {
      printWindow.focus()
      printWindow.print()
    }, 500)
  }
}

function formatDate(d) {
  return d ? new Date(d).toLocaleString() : '-'
}

function activityIcon(action) {
  const map = {
    created: 'add_circle',
    status_change: 'sync',
    diagnosis_added: 'search',
    part_added: 'category',
    report_generated: 'description',
    note_added: 'note',
    approval: 'check_circle',
    payment_update: 'payments',
    assignment_change: 'person',
  }
  return map[action] || 'circle'
}

function activityColor(action) {
  const map = {
    created: 'blue',
    status_change: 'purple',
    diagnosis_added: 'orange',
    part_added: 'green',
    report_generated: 'teal',
    approval: 'positive',
    payment_update: 'amber',
  }
  return map[action] || 'grey'
}

onMounted(async () => {
  const jobId = route.params.id
  if (!jobId) {
    router.push('/services/jobs')
    return
  }
  // Load inventory items for part picker (don't block job loading)
  loadInventoryItems()
  try {
    await store.fetchJob(jobId)
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to load job: ' + err.message })
    router.push('/services/jobs')
  }
})
</script>

<style scoped lang="scss">
.glass-card {
  background: v-bind("$q.dark.isActive ? 'rgba(30,30,40,0.45)' : 'rgba(255,255,255,0.6)'");
  backdrop-filter: blur(20px) saturate(180%);
  border: 1px solid v-bind("$q.dark.isActive ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'");
  border-radius: 20px;
  box-shadow: 0 4px 20px 0 rgba(0, 0, 0, 0.02);
}

.cost-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 110px;
  border-radius: 12px;
}
</style>
