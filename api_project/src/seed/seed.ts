/**
 * Données de démonstration : un vendeur et 5 annonces en ligne (celles du site vitrine).
 * Usage : npm run build && npm run seed   (idempotent : ne fait rien si le vendeur existe déjà)
 */
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { AppModule } from '../app.module.js';
import type { CreateListingDto } from '../listings/dto/listing.dto.js';
import { ListingsService } from '../listings/listings.service.js';
import { PhotosService } from '../photos/photos.service.js';
import { UsersService } from '../users/users.service.js';

const DEMO_PHONE = '+2250700000001';

const LISTINGS: (CreateListingDto & { photo: string })[] = [
  {
    photo: 'villa-contemporaine.webp',
    title: 'Villa contemporaine',
    description: 'Villa lumineuse de 5 pièces avec jardin arboré, dans un quartier calme proche des écoles.',
    propertyType: 'villa',
    rooms: 5,
    bedrooms: 4,
    bathrooms: 3,
    amenities: ['garden', 'parking', 'air_conditioning', 'security'],
    city: 'Abidjan',
    district: 'Cocody, Angré',
    location: { lat: 5.3964, lng: -3.9906 },
    offers: { monthly: { rent: 650000, terms: '3 mois de caution, 2 mois d’avance' } },
  },
  {
    photo: 'appartement-lumineux.webp',
    title: 'Appartement lumineux',
    description: 'Appartement de 3 pièces avec balcon, au 2e étage d’une résidence sécurisée.',
    propertyType: 'apartment',
    rooms: 3,
    bedrooms: 2,
    bathrooms: 1,
    amenities: ['balcony', 'air_conditioning', 'security', 'water_tank'],
    city: 'Abidjan',
    district: 'Riviera Palmeraie',
    location: { lat: 5.372, lng: -3.944 },
    offers: { monthly: { rent: 350000 } },
  },
  {
    photo: 'chambre.webp',
    title: 'Studio meublé',
    description: 'Studio entièrement meublé et équipé, idéal pour un séjour professionnel.',
    propertyType: 'studio',
    rooms: 1,
    bedrooms: 1,
    bathrooms: 1,
    amenities: ['furnished', 'wifi', 'air_conditioning'],
    city: 'Abidjan',
    district: 'Marcory, Zone 4',
    location: { lat: 5.3009, lng: -3.9887 },
    offers: { nightly: { price: 25000, minNights: 2 } },
  },
  {
    photo: 'maison-jardin.webp',
    title: 'Maison familiale',
    description: 'Maison de 4 pièces avec terrasse et cour, au calme.',
    propertyType: 'house',
    rooms: 4,
    bedrooms: 3,
    bathrooms: 2,
    amenities: ['parking', 'garden', 'generator'],
    city: 'Bingerville',
    district: 'Bingerville Centre',
    location: { lat: 5.355, lng: -3.885 },
    offers: { monthly: { rent: 400000 }, sale: { price: 85000000 } },
  },
  {
    photo: 'villa-piscine.webp',
    title: 'Maison de vacances',
    description: 'Maison de 3 pièces avec piscine, à quelques minutes de la plage.',
    propertyType: 'house',
    rooms: 3,
    bedrooms: 3,
    bathrooms: 2,
    amenities: ['pool', 'furnished', 'air_conditioning', 'wifi'],
    city: 'Assinie',
    district: 'Assinie-Mafia',
    location: { lat: 5.134, lng: -3.47 },
    offers: { nightly: { price: 90000, minNights: 2 } },
  },
];

async function seed() {
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn'] });
  try {
    const users = app.get(UsersService);
    if (await users.findActiveByPhone(DEMO_PHONE)) {
      console.log('Données de démonstration déjà présentes : rien à faire.');
      return;
    }
    const seller = await users.create(DEMO_PHONE, 'WELLY Démo');
    seller.isSeller = true;
    await users.repo.save(seller);

    const listings = app.get(ListingsService);
    const photos = app.get(PhotosService);
    for (const { photo, ...dto } of LISTINGS) {
      const listing = await listings.create(seller.id, dto);
      const buffer = await readFile(join(process.cwd(), 'seed', 'photos', photo));
      await photos.add(seller.id, listing.id, [{ buffer } as Express.Multer.File]);
      await listings.publish(seller.id, listing.id);
      console.log(`✓ ${dto.title} — ${dto.district}`);
    }
    console.log(`${LISTINGS.length} annonces de démonstration créées.`);
  } finally {
    await app.close();
  }
}

await seed();
