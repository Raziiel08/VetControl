<script setup>
import { Check } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'

const { mensaje } = useToast()
</script>

<template>
  <transition name="toast">
    <div v-if="mensaje" class="toast-message" role="status" aria-live="polite">
      <Check /> {{ mensaje }}
    </div>
  </transition>
</template>
