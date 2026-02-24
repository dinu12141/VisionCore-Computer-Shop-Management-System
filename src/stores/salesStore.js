import { defineStore } from 'pinia'
import { supabase } from 'src/boot/supabase'

export const useSalesStore = defineStore('sales', {
  state: () => ({
    cartItems: [],
    taxRate: 0.15, // 15% VAT placeholder
    discountRate: 0,
    loading: false,
    error: null,
    orderType: 'Standard', // Standard, Repair, etc.
  }),

  getters: {
    itemCount: (state) => state.cartItems.reduce((sum, item) => sum + item.quantity, 0),
    subtotal: (state) => state.cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0),
    discountTotal: (state) => {
      const sub = state.cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0)
      return sub * (state.discountRate / 100)
    },
    taxTotal: (state) => {
      const sub = state.cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0)
      const disc = sub * (state.discountRate / 100)
      return (sub - disc) * state.taxRate
    },
    total: (getters) => getters.subtotal - getters.discountTotal + getters.taxTotal,
    isEmpty: (state) => state.cartItems.length === 0,
  },

  actions: {
    async addItemBySN(serialNumber) {
      if (!serialNumber) return

      this.loading = true
      try {
        // Find SN in database
        const { data, error } = await supabase
          .from('item_serials')
          .select('*, item:items(*)')
          .eq('serial_number', serialNumber)
          .eq('status', 'available')
          .single()

        if (error || !data) {
          throw new Error('Serial number not found or already sold.')
        }

        const product = {
          id: data.item.id,
          name: data.item.name,
          price: data.item.sale_price
            ? parseFloat(data.item.sale_price)
            : parseFloat(data.item.last_purchase_price || 0) * 1.25,
          image:
            'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400&h=300&fit=crop',
          category: data.item.category || 'Hardware',
          warranty: data.item.warranty || '',
        }

        this.addItem(product, null, serialNumber)
      } catch (err) {
        this.error = err.message
        throw err
      } finally {
        this.loading = false
      }
    },

    addItem(product, variant = null, serialNumber = null) {
      if (serialNumber) {
        // SNs are unique units
        const exists = this.cartItems.find((i) => i.serialNumber === serialNumber)
        if (exists) return

        this.cartItems.push({
          ...product,
          variant,
          serialNumber,
          quantity: 1,
          isSNCtrl: true,
          warranty: product.warranty || '',
        })
      } else {
        const existing = this.cartItems.find(
          (item) => item.id === product.id && item.variant === variant && !item.serialNumber,
        )

        if (existing) {
          existing.quantity += 1
        } else {
          this.cartItems.push({
            ...product,
            variant,
            serialNumber: null,
            quantity: 1,
            isSNCtrl: false,
            warranty: product.warranty || '',
          })
        }
      }
    },

    updateQuantity(itemId, variant, quantity, serialNumber = null) {
      const item = this.cartItems.find(
        (i) => i.id === itemId && i.variant === variant && i.serialNumber === serialNumber,
      )
      if (item) {
        if (item.isSNCtrl) {
          item.quantity = 1 // SN items can only be 1
        } else {
          item.quantity = quantity
        }

        if (item.quantity <= 0) {
          this.removeItem(itemId, variant, serialNumber)
        }
      }
    },

    removeItem(itemId, variant, serialNumber = null) {
      this.cartItems = this.cartItems.filter(
        (i) => !(i.id === itemId && i.variant === variant && i.serialNumber === serialNumber),
      )
    },

    setDiscount(rate) {
      this.discountRate = rate
    },

    clearCart() {
      this.cartItems = []
      this.discountRate = 0
    },

    async processPayment(method) {
      this.loading = true
      try {
        // In reality, this would save to Supabase.
        // We'll simulate a 1s delay.
        await new Promise((r) => setTimeout(r, 1000))

        const invoiceNumber = 'INV-' + Date.now().toString().slice(-6)

        // This data will be used for printing
        const saleRecord = {
          invoiceNumber,
          timestamp: new Date().toLocaleString(),
          items: [...this.cartItems],
          subtotal: this.subtotal,
          taxTotal: this.taxTotal,
          discountTotal: this.discountTotal,
          total: this.total,
          paymentMethod: method,
        }

        this.clearCart()
        return { success: true, invoiceNumber, saleRecord }
      } catch (err) {
        this.error = err.message
        throw err
      } finally {
        this.loading = false
      }
    },

    async submitOrder() {
      // Mock order submission (Quotation or Pending)
      this.loading = true
      try {
        await new Promise((r) => setTimeout(r, 800))
        return {
          success: true,
          order: { id: Date.now(), order_number: 'QT-' + Date.now().toString().slice(-4) },
        }
      } finally {
        this.loading = false
      }
    },
  },
})
