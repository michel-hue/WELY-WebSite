/** Stockage des fichiers médias. Implémentation choisie par STORAGE_DRIVER. */
export interface Storage {
  put(key: string, body: Buffer, contentType: string): Promise<void>;
  delete(key: string): Promise<void>;
  publicUrl(key: string): string;
}

export const STORAGE = Symbol('STORAGE');
