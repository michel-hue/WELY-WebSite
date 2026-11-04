<template>
  <div>
    <PageHero eyebrow="Contact">
      <template #title>Parlons de <span class="serif">votre projet.</span></template>
      Une question sur l'application, un partenariat ou une suggestion ? Notre équipe vous répond.
    </PageHero>

    <section class="section contact">
      <div class="container contact__grid">
        <aside class="contact__info">
          <div v-for="(b, i) in blocks" :key="b.title" class="contact__block" v-reveal="i * 80">
            <LineIcon :name="b.icon" :size="26" />
            <div>
              <h2>{{ b.title }}</h2>
              <a v-for="l in b.lines" :key="l.text" :href="l.href || undefined">{{ l.text }}</a>
            </div>
          </div>
        </aside>

        <form class="contact__form" novalidate v-reveal="120" @submit.prevent="submitForm">
          <h2 class="contact__form-title">Envoyez-nous un message</h2>

          <div class="field-row">
            <div class="field" :class="{ 'has-error': errors.name }">
              <label for="name">Nom</label>
              <input id="name" v-model="form.name" type="text" autocomplete="name" required :aria-invalid="!!errors.name" aria-describedby="name-err" />
              <span id="name-err" class="field__error">{{ errors.name }}</span>
            </div>
            <div class="field" :class="{ 'has-error': errors.email }">
              <label for="email">Email</label>
              <input id="email" v-model="form.email" type="email" autocomplete="email" required :aria-invalid="!!errors.email" aria-describedby="email-err" />
              <span id="email-err" class="field__error">{{ errors.email }}</span>
            </div>
          </div>

          <div class="field" :class="{ 'has-error': errors.subject }">
            <label for="subject">Sujet</label>
            <input id="subject" v-model="form.subject" type="text" required :aria-invalid="!!errors.subject" aria-describedby="subject-err" />
            <span id="subject-err" class="field__error">{{ errors.subject }}</span>
          </div>

          <div class="field" :class="{ 'has-error': errors.message }">
            <label for="message">Message</label>
            <textarea id="message" v-model="form.message" rows="6" required :aria-invalid="!!errors.message" aria-describedby="message-err"></textarea>
            <span id="message-err" class="field__error">{{ errors.message }}</span>
          </div>

          <button type="submit" class="btn btn--dark" :disabled="submitting">Envoyer le message</button>
          <p v-if="success" class="contact__success" role="status">{{ success }}</p>
          <p v-if="errorMessage" class="field__error" role="alert">{{ errorMessage }}</p>
        </form>
      </div>
    </section>

    <FaqList />
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'

useHead({ title: 'Contact — WELLY' })

const blocks = [
  { icon: 'mail', title: 'Demandes générales', lines: [{ text: 'work@wely.com', href: 'mailto:work@wely.com' }, { text: '+225 07 00 00 00', href: 'tel:+2250700000000' }] },
  { icon: 'inbox', title: 'Partenariats', lines: [{ text: 'partnerships@wely.com', href: 'mailto:partnerships@wely.com' }, { text: '+225 05 00 00 00', href: 'tel:+2250500000000' }] },
  { icon: 'pin', title: 'Adresse', lines: [{ text: 'Abidjan, Côte d’Ivoire', href: '' }] }
] as const

const form = reactive({ name: '', email: '', subject: '', message: '' })
const errors = reactive({ name: '', email: '', subject: '', message: '' })
const submitting = ref(false)
const success = ref('')
const errorMessage = ref('')

function validate() {
  errors.name = form.name.trim() ? '' : 'Le nom est requis.'
  errors.email = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email) ? '' : 'Email invalide.'
  errors.subject = form.subject.trim() ? '' : 'Le sujet est requis.'
  errors.message = form.message.trim().length >= 10 ? '' : 'Le message doit contenir au moins 10 caractères.'
  return !errors.name && !errors.email && !errors.subject && !errors.message
}

function submitForm() {
  if (!validate()) return
  submitting.value = true
  success.value = ''
  errorMessage.value = ''
  try {
    // Pas encore d'endpoint : on ouvre le client mail de l'utilisateur.
    const body = encodeURIComponent(`Nom: ${form.name}\nEmail: ${form.email}\n\n${form.message}`)
    window.location.href = `mailto:work@wely.com?subject=${encodeURIComponent(form.subject)}&body=${body}`
    success.value = 'Votre messagerie s’est ouverte. Merci pour votre message !'
    Object.assign(form, { name: '', email: '', subject: '', message: '' })
  } catch {
    errorMessage.value = 'Une erreur est survenue. Veuillez réessayer.'
  } finally {
    submitting.value = false
  }
}
</script>

<style lang="scss">
@import "../../assets/scss/contact";
</style>
