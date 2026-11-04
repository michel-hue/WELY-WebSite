import { mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import type { Storage } from './storage.js';

/** Fichiers sur le disque, servis par l'API sous /media (développement). */
export class LocalStorage implements Storage {
  readonly root: string;

  constructor(
    dir: string,
    private readonly baseUrl = '/media',
  ) {
    this.root = resolve(dir);
  }

  private path(key: string) {
    const p = resolve(join(this.root, key));
    if (!p.startsWith(this.root)) throw new Error('Clé de média invalide');
    return p;
  }

  async put(key: string, body: Buffer): Promise<void> {
    const p = this.path(key);
    await mkdir(dirname(p), { recursive: true });
    await writeFile(p, body);
  }

  async delete(key: string): Promise<void> {
    await rm(this.path(key), { force: true });
  }

  publicUrl(key: string): string {
    return `${this.baseUrl.replace(/\/$/, '')}/${key}`;
  }
}
