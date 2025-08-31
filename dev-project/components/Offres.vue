<template>
  <main class="main-content">

    <!-- SECTION MEILLEURES OFFRES -->
    <section class="popular-offers">
      <h2 class="section-title1">Nos Meilleures Offres</h2>
      <p class="section-intro">
        Découvrez un aperçu des résidences les plus demandées sur Wely.  

      </p>
      <div class="cards-container">
        
        <div class="card">
          <img src="/image9.jpg" alt="Villa familiale">
          <div class="card-body">
            <h3>Villa Familiale</h3>
            <p>Bouaké</p>
            <div class="rating">★★★★☆ <span>(12 avis)</span></div>
            <span class="price">500 000 FCFA / mois</span>
            <button class="cta-small">Voir détails</button>
          </div>
        </div>

        <div class="card">
          <img src="/image8.jpg" alt="Appartement moderne">
          <div class="card-body">
            <h3>Appartement Moderne</h3>
            <p>Abidjan</p>
            <div class="rating">★★★★★ <span>(18 avis)</span></div>
            <span class="price">350 000 FCFA / mois</span>
            <button class="cta-small">Voir détails</button>
          </div>
        </div>

        <div class="card">
          <img src="/image7.jpg" alt="Studio étudiant">
          <div class="card-body">
            <h3>Studio Étudiant</h3>
            <p>Yamoussoukro</p>
            <div class="rating">★★★☆☆ <span>(7 avis)</span></div>
            <span class="price">120 000 FCFA / mois</span>
            <button class="cta-small">Voir détails</button>
          </div>
        </div>

      </div>
    </section>

    <!-- SECTION OFFRES PAR VILLES -->
    <section class="city-offers">
      <h2 class="section-title">Explorer par Villes</h2>
      <p class="section-intro">
        Wely regroupe des centaines d’offres dans les plus grandes villes de Côte d’Ivoire.  
        Publiez votre bien ou trouvez la résidence idéale en un clic !
      </p>
      <div class="cities-container">
        
        <div class="city-card">
          <img src="/image7.jpg" alt="Abidjan">
          <div class="overlay-city">
            <h3>Abidjan</h3>
            <p>120+ Offres</p>
          </div>
        </div>

        <div class="city-card">
          <img src="/image8.jpg" alt="Yamoussoukro">
          <div class="overlay-city">
            <h3>Yamoussoukro</h3>
            <p>80+ Offres</p>
          </div>
        </div>

        <div class="city-card">
          <img src="/image9.jpg" alt="Bouaké">
          <div class="overlay-city">
            <h3>Bouaké</h3>
            <p>60+ Offres</p>
          </div>
        </div>

      </div>
      <div class="more-btn1">
        <button class="cta2">Voir plus</button>
      </div>
    </section>

  </main>
</template>

<style lang="scss">
@import '../../assets/scss/offres'
</style>