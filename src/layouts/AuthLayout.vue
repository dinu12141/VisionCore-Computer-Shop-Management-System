<template>
  <q-layout view="hHh lpR fFf" class="auth-layout">
    <div class="auth-bg-split">
      <div class="split-left"></div>
      <div class="split-right"></div>
    </div>
    <q-page-container class="auth-container">
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<style scoped lang="scss">
.auth-layout {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
}

.auth-bg-split {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
  display: flex;

  .split-left {
    flex: 1;
    background: #3498db; // Solid branding color
  }

  .split-right {
    flex: 1;
    background: #f0f2f5; // Neutral light gray
  }
}

.auth-container {
  height: 100vh;
  overflow: hidden;
  z-index: 1;
}
</style>
