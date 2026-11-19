<script setup>
import { Check } from "lucide-vue-next";
import { useToast } from "@/composables/useToast";

const { mensaje } = useToast();
</script>

<template>
  <transition name="aviso">
    <div v-if="mensaje" class="mensaje-toast" role="status" aria-live="polite">
      <Check /> {{ mensaje }}
    </div>
  </transition>
</template>
