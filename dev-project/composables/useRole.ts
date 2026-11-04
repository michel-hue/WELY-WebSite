// Rôle affiché sur le site : « Je cherche » (acheteur) ou « Je propose » (vendeur).
// Partagé entre l'ouverture de l'accueil et la section « Comment ça marche ».
export type Role = 'buyer' | 'seller'

export const useRole = () => useState<Role>('role', () => 'buyer')
