import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { IsNull, MoreThan, Repository } from 'typeorm';
import { badRequest, tooMany, unauthorized } from '../common/errors/app-error.js';
import type { Env } from '../config/env.validation.js';
import { toMeDto, type MeDto } from '../users/me.dto.js';
import { UsersService } from '../users/users.service.js';
import { OtpChallenge } from './otp-challenge.entity.js';
import {
  evaluateOtpAttempt,
  generateOtp,
  hashOtp,
  OTP_MAX_ATTEMPTS,
  OTP_MAX_SENDS_PER_HOUR,
  OTP_RESEND_COOLDOWN_MS,
  OTP_TTL_MS,
} from './otp/otp-rules.js';
import { OTP_SENDER, type OtpChannel, type OtpSender } from './otp/otp-sender.js';
import { normalizePhone } from './phone.js';
import { RefreshToken } from './refresh-token.entity.js';

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  user: MeDto;
}

const OTP_INVALID = () => unauthorized('OTP_INVALID', 'Code incorrect ou expiré.');
const REFRESH_INVALID = () => unauthorized('REFRESH_INVALID', 'Session expirée, reconnectez-vous.');
/** Délai pendant lequel un jeton tout juste remplacé peut encore servir (requête rejouée). */
const REFRESH_REUSE_GRACE_MS = 30_000;
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(OtpChallenge) private readonly challenges: Repository<OtpChallenge>,
    @InjectRepository(RefreshToken) private readonly tokens: Repository<RefreshToken>,
    @Inject(OTP_SENDER) private readonly sender: OtpSender,
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService<Env, true>,
  ) {}

  private get secret() {
    return this.cfg.get('JWT_SECRET', { infer: true });
  }

  async requestOtp(rawPhone: string, channel: OtpChannel = 'sms') {
    const phone = normalizePhone(rawPhone);
    const now = Date.now();
    const recent = await this.challenges.find({
      where: { phone, createdAt: MoreThan(new Date(now - 60 * 60 * 1000)) },
      order: { createdAt: 'DESC' },
    });
    if (recent[0] && now - recent[0].createdAt.getTime() < OTP_RESEND_COOLDOWN_MS) {
      throw tooMany('OTP_RESEND_TOO_SOON', 'Patientez une minute avant de demander un nouveau code.');
    }
    if (recent.length >= OTP_MAX_SENDS_PER_HOUR) {
      throw tooMany('OTP_TOO_MANY_REQUESTS', 'Trop de codes demandés. Réessayez dans une heure.');
    }

    // Un seul code valide à la fois : les précédents sont invalidés.
    await this.challenges.update({ phone, consumedAt: IsNull() }, { consumedAt: new Date(now) });
    const code = generateOtp();
    await this.challenges.save(
      this.challenges.create({
        phone,
        channel,
        codeHash: hashOtp(code, this.secret),
        expiresAt: new Date(now + OTP_TTL_MS),
      }),
    );
    await this.sender.send(phone, code, channel);
    const existing = await this.users.findActiveByPhone(phone);
    return { expiresInSeconds: OTP_TTL_MS / 1000, isNewUser: !existing };
  }

  async verifyOtp(rawPhone: string, code: string, rawName?: string): Promise<AuthSession> {
    const phone = normalizePhone(rawPhone);
    const challenge = await this.challenges.findOne({ where: { phone, consumedAt: IsNull() }, order: { createdAt: 'DESC' } });
    if (!challenge) throw OTP_INVALID();

    // Chaque essai est réservé atomiquement : des essais envoyés en parallèle ne dépassent pas la limite.
    const [reserved]: [{ attempts: number }[], number] = await this.challenges.query(
      `UPDATE otp_challenges SET attempts = attempts + 1
       WHERE id = $1 AND attempts < $2 AND consumed_at IS NULL AND expires_at > now()
       RETURNING attempts`,
      [challenge.id, OTP_MAX_ATTEMPTS],
    );
    if (!reserved.length) {
      if (challenge.attempts >= OTP_MAX_ATTEMPTS || challenge.expiresAt.getTime() > Date.now()) {
        throw tooMany('OTP_TOO_MANY_ATTEMPTS', 'Trop d’essais. Demandez un nouveau code.');
      }
      throw OTP_INVALID();
    }
    // L'essai réservé est compté : on évalue le code avec le compteur d'avant.
    const outcome = evaluateOtpAttempt({ ...challenge, attempts: reserved[0].attempts - 1 }, code, new Date(), this.secret);
    if (outcome !== 'ok') throw OTP_INVALID();

    let user = await this.users.findActiveByPhone(phone);
    const name = rawName?.trim();
    if (!user && (!name || name.length < 2)) {
      // Le code n'est pas consommé : l'app peut renvoyer la demande avec le nom.
      throw badRequest('VALIDATION_ERROR', 'Certaines informations sont invalides.', [
        { field: 'name', message: 'Indiquez votre nom (2 caractères minimum).' },
      ]);
    }
    // Le code ne peut ouvrir qu'une seule session.
    const { affected } = await this.challenges.update({ id: challenge.id, consumedAt: IsNull() }, { consumedAt: new Date() });
    if (!affected) throw OTP_INVALID();
    user ??= await this.users.create(phone, name!);
    return this.issueSession(user.id, randomUUID());
  }

  async refresh(refreshToken: string): Promise<AuthSession> {
    const token = await this.tokens.findOne({ where: { tokenHash: sha256(refreshToken) } });
    if (!token) throw REFRESH_INVALID();
    if (token.revokedAt && Date.now() - token.revokedAt.getTime() < REFRESH_REUSE_GRACE_MS) {
      // Renouvellement rejoué juste après (réponse perdue sur un réseau mobile instable) :
      // on délivre une nouvelle session dans la même famille, sans tout révoquer.
      const user = await this.users.findActiveById(token.userId);
      if (!user || token.expiresAt.getTime() <= Date.now()) throw REFRESH_INVALID();
      return this.issueSession(user.id, token.familyId);
    }
    if (token.revokedAt) {
      // Jeton déjà remplacé puis réutilisé : vol probable, toute la session est révoquée.
      await this.tokens.update({ familyId: token.familyId, revokedAt: IsNull() }, { revokedAt: new Date() });
      throw REFRESH_INVALID();
    }
    if (token.expiresAt.getTime() <= Date.now()) throw REFRESH_INVALID();
    const user = await this.users.findActiveById(token.userId);
    if (!user) throw REFRESH_INVALID();

    const { affected } = await this.tokens.update({ id: token.id, revokedAt: IsNull() }, { revokedAt: new Date() });
    if (!affected) throw REFRESH_INVALID();
    return this.issueSession(user.id, token.familyId);
  }

  async logout(refreshToken: string): Promise<void> {
    const token = await this.tokens.findOne({ where: { tokenHash: sha256(refreshToken) } });
    if (token) await this.tokens.update({ familyId: token.familyId, revokedAt: IsNull() }, { revokedAt: new Date() });
  }

  /** Révoque toutes les sessions d'un utilisateur (suppression de compte). */
  async revokeAll(userId: string): Promise<void> {
    await this.tokens.update({ userId, revokedAt: IsNull() }, { revokedAt: new Date() });
  }

  private async issueSession(userId: string, familyId: string): Promise<AuthSession> {
    const user = await this.users.getActive(userId);
    const refreshToken = randomBytes(32).toString('base64url');
    const days = this.cfg.get('REFRESH_TTL_DAYS', { infer: true });
    await this.tokens.save(
      this.tokens.create({
        userId,
        familyId,
        tokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + days * 24 * 60 * 60 * 1000),
      }),
    );
    const accessToken = await this.jwt.signAsync({ sub: userId });
    return { accessToken, refreshToken, user: toMeDto(user) };
  }
}
