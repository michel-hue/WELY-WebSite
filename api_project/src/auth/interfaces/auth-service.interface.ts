import { UserRole } from '../../users/user.entity.js';

export interface IAuthService {
  register(email: string, password: string, role: UserRole): Promise<{ token: string; user: any }>;
  login(email: string, password: string): Promise<{ token: string; user: any }>;
}
