import { DefaultNamingStrategy, type NamingStrategyInterface } from 'typeorm';

const snake = (s: string) => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

/** Colonnes en snake_case côté SQL, propriétés en camelCase côté TypeScript. */
export class SnakeNamingStrategy extends DefaultNamingStrategy implements NamingStrategyInterface {
  override columnName(propertyName: string, customName: string | undefined, prefixes: string[]): string {
    return snake([...prefixes, customName ?? propertyName].join('_'));
  }

  override relationName(propertyName: string): string {
    return snake(propertyName);
  }

  override joinColumnName(relationName: string, referencedColumnName: string): string {
    return snake(`${relationName}_${referencedColumnName}`);
  }
}
