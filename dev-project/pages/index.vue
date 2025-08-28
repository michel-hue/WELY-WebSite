<template>
    <div>
     <header>
        <Header/>
     </header>
     <section><PresentServices/></section>
    </div>
</template>
<script setup>
import Header from '~/components/Header.vue';
import PresentServices from '~/components/PresentServices.vue';
</script>
<style lang="scss">
body{
    padding: 0;
    margin: 0;
}
</style>