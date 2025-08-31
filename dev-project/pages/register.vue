<template>
  <section class="auth-container">
    <!-- Partie gauche avec image -->
    <div class="auth-image">
      <div class="overlay">
        <h2>Devenir Propriétaire</h2>
<p>Faites de vos maisons une opportunité rentable avec Wely</p>

      </div>
    </div>

    <!-- Partie droite avec formulaire -->
    <div class="auth-form">
      <div class="form-header">
        <h2>{{ isRegister ? "Créer votre compte" : "Bienvenue sur Wely" }}</h2>
        <p>{{ isRegister ? "Inscrivez-vous pour commencer a mettre en ligne vos maison" : "Connectez-vous pour continuer" }}</p>
      </div>

      <!-- Formulaire -->
      <form @submit.prevent="handleSubmit">
        <!-- Register fields -->
        <div v-if="isRegister">
          <div class="form-group">
            <input type="text" placeholder="First Name" v-model="form.firstName" required />
          </div>
          <div class="form-group">
            <input type="text" placeholder="Last Name" v-model="form.lastName" required />
          </div>
          <div class="form-group">
            <input type="email" placeholder="Your Email" v-model="form.email" required />
          </div>
          <div class="form-group">
            <input type="password" placeholder="Password" v-model="form.password" required />
          </div>
          <div class="form-group">
            <input type="password" placeholder="Confirm Password" v-model="form.confirmPassword" required />
          </div>
        </div>

        <!-- Login fields -->
        <div v-else>
          <div class="form-group">
            <input type="email" placeholder="Your Email" v-model="form.email" required />
          </div>
          <div class="form-group">
            <input type="password" placeholder="Password" v-model="form.password" required />
          </div>
          <div class="form-options">
            <label>
              <input type="checkbox" v-model="form.remember" />
              Se souvenir de moi
            </label>
            <a href="#">Mot de passe oublié ?</a>
          </div>
        </div>

        <!-- Bouton -->
        <button type="submit" class="btn-primary">
          {{ isRegister ? "S’inscrire" : "Se Connecter" }}
        </button>
      </form>

      <!-- Switch login/register -->
      <p class="switch-text">
       {{ isLogin ? "Vous n’avez pas de compte ?" : "Vous avez déjà un compte ?" }}
        <a href="#" @click.prevent="toggleForm">
          {{ isRegister ? "Se connecter" : "S’inscrire" }}
        </a>
      </p>
    </div>
  </section>
</template>

<script>
export default {
  name: "AuthPage",
  data() {
    return {
      isRegister: true, 
      form: {
        firstName: "",
        lastName: "",
        email: "",
        password: "",
        confirmPassword: "",
        remember: false,
      },
    };
  },
  methods: {
    toggleForm() {
      this.isRegister = !this.isRegister;
      this.form = {
        firstName: "",
        lastName: "",
        email: "",
        password: "",
        confirmPassword: "",
        remember: false,
      };
    },
    handleSubmit() {
      if (this.isRegister && this.form.password !== this.form.confirmPassword) {
        alert("Les mots de passe ne correspondent pas !");
        return;
      }
      alert(this.isRegister ? "Inscription envoyée !" : "Connexion envoyée !");
    },
  },
};
</script>

<style lang="scss" scoped>
@import "../../assets/scss/register";
</style>
