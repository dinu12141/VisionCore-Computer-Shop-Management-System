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
          <q-btn flat icon="print" label="Report" @click="openReportDialog" color="secondary" />
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

              <!-- Costs -->
              <div class="col-12">
                <div class="text-subtitle2 text-weight-bold q-mb-sm">Cost Summary</div>
                <div class="row q-col-gutter-md">
                  <!-- Estimated -->
                  <div class="col-4">
                    <q-card
                      flat
                      bordered
                      class="cost-card q-pa-md text-center"
                      :dark="$q.dark.isActive"
                    >
                      <div class="text-caption text-grey q-mb-xs">Estimated</div>
                      <div class="text-h6 text-weight-bold">
                        LKR {{ Number(job.total_estimated_cost || 0).toLocaleString() }}
                      </div>
                    </q-card>
                  </div>

                  <!-- Final -->
                  <div class="col-4">
                    <q-card
                      flat
                      bordered
                      class="cost-card q-pa-md text-center"
                      :dark="$q.dark.isActive"
                    >
                      <div class="text-caption text-grey q-mb-xs">Final</div>
                      <div class="text-h6 text-weight-bold text-primary">
                        LKR {{ Number(job.total_final_cost || 0).toLocaleString() }}
                      </div>
                    </q-card>
                  </div>

                  <!-- Payment -->
                  <div class="col-4">
                    <q-card
                      flat
                      bordered
                      class="cost-card q-pa-md text-center"
                      :dark="$q.dark.isActive"
                    >
                      <div class="text-caption text-grey q-mb-sm">Payment</div>

                      <!-- Status badge + dropdown to change status -->
                      <div class="flex flex-center q-mb-sm">
                        <q-btn-dropdown flat dense no-caps :dark="$q.dark.isActive">
                          <template v-slot:label>
                            <q-badge
                              :color="
                                job.payment_status === 'paid'
                                  ? 'positive'
                                  : job.payment_status === 'partial'
                                    ? 'warning'
                                    : 'negative'
                              "
                              :label="job.payment_status || 'unpaid'"
                              class="text-capitalize cursor-pointer"
                              style="font-size: 13px; padding: 4px 10px"
                            />
                          </template>
                          <q-list dense :dark="$q.dark.isActive">
                            <q-item clickable v-close-popup @click="updatePayment('unpaid')">
                              <q-item-section
                                ><q-badge color="negative" label="Unpaid"
                              /></q-item-section>
                            </q-item>
                            <q-item clickable v-close-popup @click="updatePayment('partial')">
                              <q-item-section
                                ><q-badge color="warning" label="Partial"
                              /></q-item-section>
                            </q-item>
                            <q-item clickable v-close-popup @click="updatePayment('paid')">
                              <q-item-section
                                ><q-badge color="positive" label="Paid"
                              /></q-item-section>
                            </q-item>
                          </q-list>
                        </q-btn-dropdown>
                      </div>

                      <!-- Pay Now button — only shown when unpaid or partial -->
                      <q-btn
                        v-if="job.payment_status !== 'paid'"
                        unelevated
                        color="primary"
                        icon="receipt_long"
                        label="Pay → Invoice"
                        size="sm"
                        class="full-width"
                        @click="goToBillingWithJobDetails"
                      />
                    </q-card>
                  </div>
                </div>
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
                  <div class="row q-col-gutter-md">
                    <div class="col-6">
                      <q-input
                        v-model.number="diagForm.estimated_cost"
                        label="Est. Cost"
                        type="number"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                        prefix="LKR"
                      />
                    </div>
                    <div class="col-6">
                      <q-input
                        v-model.number="diagForm.final_cost"
                        label="Final Cost"
                        type="number"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                        prefix="LKR"
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
                      <q-input
                        v-model="partForm.item_name"
                        label="Part / Item Name *"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                      />
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
                    <div class="col-12 col-sm-5">
                      <q-input
                        v-model.number="partForm.unit_price"
                        label="Unit Price"
                        type="number"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                        prefix="LKR"
                      />
                    </div>
                    <div class="col-12 col-sm-4">
                      <q-input
                        :model-value="partForm.qty * partForm.unit_price"
                        label="Total"
                        type="number"
                        outlined
                        dense
                        :dark="$q.dark.isActive"
                        prefix="LKR"
                        readonly
                      />
                    </div>
                    <div class="col-12">
                      <q-input
                        v-model="partForm.notes"
                        label="Notes"
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
                <q-item-section side>
                  <q-btn flat icon="print" color="primary" @click="printReport(rpt)" size="sm">
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
          <div class="text-h6">Generate Service Report</div>
          <q-space /><q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>
        <q-separator />
        <q-card-section class="q-gutter-md">
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
          <q-input
            v-model="reportForm.summary"
            label="Summary Notes"
            type="textarea"
            rows="3"
            outlined
            dense
            :dark="$q.dark.isActive"
          />
          <div class="text-subtitle2 q-mt-sm">Include Sections</div>
          <div class="q-gutter-sm">
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
              v-model="reportForm.includeCosts"
              label="Cost Summary"
              dense
              color="primary"
            />
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

const $q = useQuasar()
const route = useRoute()
const router = useRouter()
const store = useServiceStore()

const activeTab = ref('overview')
const showDiagDialog = ref(false)
const showPartDialog = ref(false)
const showReportDialog = ref(false)
const generatingReport = ref(false)

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
  estimated_cost: 0,
  final_cost: 0,
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
  {
    name: 'estimated_cost',
    label: 'Est. Cost',
    field: 'estimated_cost',
    align: 'right',
    format: (v) => 'LKR ' + Number(v || 0).toLocaleString(),
  },
  {
    name: 'final_cost',
    label: 'Final Cost',
    field: 'final_cost',
    align: 'right',
    format: (v) => 'LKR ' + Number(v || 0).toLocaleString(),
  },
  { name: 'is_fixed', label: 'Fixed', field: 'is_fixed', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

// Parts form
const partForm = reactive({
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
    format: (v) => 'LKR ' + Number(v || 0).toLocaleString(),
  },
  {
    name: 'total',
    label: 'Total',
    field: 'total',
    align: 'right',
    format: (v) => 'LKR ' + Number(v || 0).toLocaleString(),
  },
  { name: 'notes', label: 'Notes', field: 'notes', align: 'left' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

// Report form
const reportForm = reactive({
  type: 'inspection',
  summary: '',
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

async function updatePayment(status) {
  try {
    await store.updatePaymentStatus(job.value.id, status)
    $q.notify({ type: 'positive', message: `Payment status updated to ${status}` })
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to update payment status: ' + err.message })
  }
}

// Navigate to billing and pre-fill all service job details
function goToBillingWithJobDetails() {
  const j = job.value
  if (!j) return

  // Use final cost if available, otherwise fall back to estimated cost
  const servicePrice =
    Number(j.total_final_cost || 0) > 0
      ? Number(j.total_final_cost)
      : Number(j.total_estimated_cost || 0)

  // Parts used as separate line items
  const partLines = (store.partsUsed || []).map((p) => ({
    name: p.item_name,
    qty: Number(p.qty || 1),
    price: Number(p.unit_price || 0),
    total: Number(p.total || p.qty * p.unit_price || 0),
  }))

  const prefill = {
    source: 'service_job',
    job_id: j.id,
    job_no: j.job_no,
    // Issue Reported goes into notes field on invoice
    notes: j.issue_reported_by_customer || `Service Job: ${j.job_no}`,
    // Customer details
    customer_id: j.customer_id || null,
    customer_name: j.customer?.name || null,
    customer_phone: j.customer?.phone || null,
    // Parts used
    items: partLines,
    // Service charge line — description = Issue Reported text, price = final/estimated cost
    service_total: servicePrice,
    service_label: j.issue_reported_by_customer
      ? `${j.job_no} — ${j.issue_reported_by_customer}`
      : `${j.job_no} — Service Charge (${j.brand || ''} ${j.model || ''})`.trim(),
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
      estimated_cost: 0,
      final_cost: 0,
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
  if (!partForm.item_name) {
    $q.notify({ type: 'warning', message: 'Part name is required' })
    return
  }
  try {
    await store.addPart(job.value.id, { ...partForm })
    showPartDialog.value = false
    Object.assign(partForm, { item_name: '', qty: 1, unit_price: 0, notes: '' })
    $q.notify({ type: 'positive', message: 'Part added' })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

async function removePart(id) {
  try {
    await store.deletePart(id)
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  }
}

function openReportDialog() {
  showReportDialog.value = true
}

async function generateReport() {
  generatingReport.value = true
  try {
    const content = {
      report_type: reportForm.type,
      summary: reportForm.summary,
      job: { ...job.value },
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

    const report = await store.createReport(job.value.id, reportForm.type, content)
    showReportDialog.value = false

    // Print report
    printReport(report)

    $q.notify({ type: 'positive', message: `Report ${report.report_no} generated` })
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message })
  } finally {
    generatingReport.value = false
  }
}

function printReport(report) {
  const content = report.content_json || {}
  const j = content.job || job.value || {}
  const diag = content.diagnosis || []
  const parts = content.parts || []
  const sections = content.sections || {}

  const title =
    report.report_type === 'inspection'
      ? 'Service Inspection Report'
      : report.report_type === 'final'
        ? 'Service Completion Report'
        : 'Service Report'

  let html = `
    <html><head><title>${title}</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: 'Segoe UI', sans-serif; padding: 40px; color: #1a1a2e; }
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
      .costs-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; text-align: center; }
      .cost-box { border: 1px solid #ddd; border-radius: 8px; padding: 12px; }
      .cost-box .value { font-size: 18px; font-weight: 700; color: #4f46e5; }
      .warranty { background: #fff3e0; border: 1px solid #ffe0b2; border-radius: 8px; padding: 12px; margin-top: 20px; }
      .signatures { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; margin-top: 40px; }
      .sig-box { border-top: 1px solid #333; padding-top: 8px; text-align: center; font-size: 12px; }
      .footer { text-align: center; margin-top: 40px; font-size: 11px; color: #999; border-top: 1px solid #eee; padding-top: 12px; }
      @media print {
        body { padding: 5px; font-size: 11px; color: #000; }
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
        <img src="/logo.jpg" alt="Vision Computers">
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

  // Issue
  html += `
    <div class="section">
      <div class="section-title">Issue Reported</div>
      <p style="font-size:13px">${j.issue_reported_by_customer || 'N/A'}</p>
    </div>`

  // Diagnosis
  if (sections.diagnosis !== false && diag.length) {
    html += `
      <div class="section">
        <div class="section-title">Diagnosed Issues</div>
        <table>
          <tr><th>Category</th><th>Issue</th><th>Severity</th><th>Fix</th><th>Est. Cost</th><th>Final Cost</th><th>Fixed</th></tr>
          ${diag
            .map(
              (d) => `<tr>
            <td>${d.category || '-'}</td><td>${d.error_title}</td><td>${d.severity}</td>
            <td>${d.recommended_fix || '-'}</td><td>LKR ${Number(d.estimated_cost || 0).toLocaleString()}</td>
            <td>LKR ${Number(d.final_cost || 0).toLocaleString()}</td><td>${d.is_fixed ? '✅' : '❌'}</td>
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
          <tr><th>Item</th><th>Qty</th><th>Unit Price</th><th>Total</th><th>Notes</th></tr>
          ${parts
            .map(
              (p) => `<tr>
            <td>${p.item_name || '-'}</td><td>${p.qty}</td>
            <td>LKR ${Number(p.unit_price || 0).toLocaleString()}</td>
            <td>LKR ${Number(p.total || 0).toLocaleString()}</td>
            <td>${p.notes || '-'}</td>
          </tr>`,
            )
            .join('')}
        </table>
      </div>`
  }

  // Costs
  if (sections.costs !== false) {
    html += `
      <div class="section">
        <div class="section-title">Cost Summary</div>
        <div class="costs-grid">
          <div class="cost-box"><div style="font-size:11px;color:#888">Estimated</div><div class="value">LKR ${Number(j.total_estimated_cost || 0).toLocaleString()}</div></div>
          <div class="cost-box"><div style="font-size:11px;color:#888">Final</div><div class="value">LKR ${Number(j.total_final_cost || 0).toLocaleString()}</div></div>
          <div class="cost-box"><div style="font-size:11px;color:#888">Payment Status</div><div class="value" style="text-transform:capitalize">${j.payment_status || 'unpaid'}</div></div>
        </div>
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
    <div class="signatures">
      <div><div class="sig-box">Technician Signature</div></div>
      <div><div class="sig-box">Customer Signature</div></div>
    </div>
    <div class="footer">Thank you for choosing Vision Core. For questions, contact us at support@visioncore.lk</div>
    </body></html>`

  const printWindow = window.open('', '_blank')
  printWindow.document.write(html)
  printWindow.document.close()
  printWindow.print()
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
