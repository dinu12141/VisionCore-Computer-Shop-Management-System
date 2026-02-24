import { ref, onMounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useRealtime } from './useRealtime'

export interface Order {
  id: string
  created_at: string
  status: string
  total_amount: number
  table_id: number | null
  // add other fields as necessary
}

export function useOrders() {
  const orders = ref<Order[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const { subscribe } = useRealtime()

  const fetchOrders = async () => {
    loading.value = true
    error.value = null
    try {
      // RLS should handle filtering by branch/permissions automatically if set up correctly
      const { data, error: err } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false })

      if (err) throw err
      orders.value = data as Order[]
    } catch (err: any) {
      console.error('Error fetching orders:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  const handleOrderUpdate = (payload: any) => {
    console.log('Order update received:', payload)
    const { eventType, new: newOrder, old: oldOrder } = payload

    if (eventType === 'INSERT') {
      orders.value.unshift(newOrder)
    } else if (eventType === 'UPDATE') {
      const index = orders.value.findIndex((o) => o.id === newOrder.id)
      if (index !== -1) {
        orders.value[index] = newOrder
      }
    } else if (eventType === 'DELETE') {
      orders.value = orders.value.filter((o) => o.id !== oldOrder.id)
    }
  }

  onMounted(() => {
    fetchOrders()
    subscribe('orders-channel', { table: 'orders' }, handleOrderUpdate)
  })

  return {
    orders,
    loading,
    error,
    fetchOrders,
  }
}
