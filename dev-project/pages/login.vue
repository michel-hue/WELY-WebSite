<template>
  <section class="auth-container">
    <!-- Partie gauche avec image -->
    <div class="auth-image">
      <div class="overlay">
        <h2>Devenir proprietaire</h2>
        <p>Faites de vos maisons une opportunité rentable avec Wely</p>
      </div>
    </div>

    <!-- Partie droite avec formulaire -->
    <div class="auth-form">
      <div class="form-header">
        <h2>{{ isLogin ? "Bienvenu sur Wely!" : "Créer votre Compte" }}</h2>
        <p>{{ isLogin ? "Connecter pour continuer" : "Inscrivez-vous pour commencer a mettre en ligne vos maison" }}</p>
      </div>

      <!-- Formulaire -->
      <form @submit.prevent="handleSubmit">
        <!-- Email -->
        <div v-if="!isLogin" class="form-group">
          <input type="text" placeholder="First Name" v-model="form.firstName" required />
        </div>
           <div v-if="!isLogin" class="form-group">
          <input type="text" placeholder="Last Name" v-model="form.lasttName" required />
        </div>
        <div class="form-group">
          <input type="email" placeholder="Your Email" v-model="form.email" required />
        </div>


        <!-- Password -->
        <div class="form-group">
          <input type="password" placeholder="Password" v-model="form.password" required />
        </div>

        <!-- Extra champ seulement pour Register -->
        <div v-if="!isLogin" class="form-group">
          <input type="password" placeholder="Confirm Password" v-model="form.confirmPassword" required />
        </div>


        <!-- Options pour Login -->
        <div v-if="isLogin" class="form-options">
          <label>
            <input type="checkbox" v-model="form.remember" />
            Se Souvenir de moi
          </label>
          <a href="#">Mot de passe oublié ?</a>
        </div>

        <!-- Bouton -->
        <button type="submit" class="btn-primary">
          {{ isLogin ? " Se Connecter" : "S'inscrire" }}
        </button>
      </form>


      <!-- Switch login/register -->
      <p class="switch-text">
        {{ isLogin ? "Vous n’avez pas de compte ?" : "Vous avez déjà un compte ?" }}
        <a href="#" @click.prevent="toggleForm">
          {{ isLogin ? "S'inscrire" : "Se Connecter" }}
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
      isLogin: true, 
      form: {
        email: "",
        firstName: "",
        lasttName:"",
        password: "",
        confirmPassword: "",
        remember: false,
      },
    };
  },
  methods: {
    toggleForm() {
      this.isLogin = !this.isLogin;
      this.form = { email: "", password: "", confirmPassword: "", remember: false };
    },
    handleSubmit() {
      if (!this.isLogin && this.form.password !== this.form.confirmPassword) {
        alert("Passwords do not match!");
        return;
      }
      alert(this.isLogin ? "Login submitted!" : "Register submitted!");
    },
  },
};
</script>
<style lang="scss" scoped>
@import "../../assets/scss/login";
</style>


