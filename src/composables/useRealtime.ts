import { ref, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'

export function useRealtime() {
  const channels = ref<Map<string, any>>(new Map())

  const subscribe = (
    channelName: string,
    eventConfig: { table: string; event?: string; schema?: string; filter?: string },
    callback: (payload: any) => void,
  ) => {
    if (channels.value.has(channelName)) {
      console.warn(`Channel ${channelName} already exists`)
      return
    }

    const channel = supabase
      .channel(channelName)
      .on(
        'postgres_changes' as any,
        {
          event: eventConfig.event || '*',
          schema: eventConfig.schema || 'public',
          table: eventConfig.table,
          filter: eventConfig.filter,
        },
        callback,
      )
      .subscribe()

    channels.value.set(channelName, channel)
  }

  const unsubscribe = (channelName: string) => {
    const channel = channels.value.get(channelName)
    if (channel) {
      supabase.removeChannel(channel)
      channels.value.delete(channelName)
    }
  }

  const unsubscribeAll = () => {
    channels.value.forEach((channel) => {
      supabase.removeChannel(channel)
    })
    channels.value.clear()
  }

  onUnmounted(() => {
    unsubscribeAll()
  })

  return {
    subscribe,
    unsubscribe,
    unsubscribeAll,
  }
}
