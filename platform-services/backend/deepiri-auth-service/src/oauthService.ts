import crypto from 'crypto';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('oauth-service');

interface OAuthClient {
  clientId: string;
  clientSecret: string;
  redirectUris: string[];
  scopes: string[];
  createdAt: Date;
}

interface AuthCodeData {
  clientId: string;
  redirectUri: string;
  scopes: string[];
  userId: string | null;
  createdAt: number;
}

interface TokenData {
  userId: string;
  scopes: string[];
  expiresAt: number;
}

interface RefreshTokenData extends TokenData {
  accessToken: string;
}

class OAuthService {
  private clients: Map<string, OAuthClient>;
  private authorizationCodes: Map<string, AuthCodeData>;
  private accessTokens: Map<string, TokenData>;
  private refreshTokens: Map<string, RefreshTokenData>;

  constructor() {
    this.clients = new Map();
    this.authorizationCodes = new Map();
    this.accessTokens = new Map();
    this.refreshTokens = new Map();
  }

  registerClient(req: Request, res: Response): void {
    try {
      const { clientId, clientSecret, redirectUris, scopes } = req.body;
      
      if (!clientId || !clientSecret || !redirectUris || !scopes) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const client: OAuthClient = {
        clientId,
        clientSecret: this._hashSecret(clientSecret),
        redirectUris: Array.isArray(redirectUris) ? redirectUris : [redirectUris],
        scopes: Array.isArray(scopes) ? scopes : [scopes],
        createdAt: new Date()
      };
      
      this.clients.set(clientId, client);
      logger.info('OAuth client registered', { clientId });
      res.json({ clientId, clientSecret });
    } catch (error) {
      logger.error('Error registering client:', error);
      res.status(500).json({ error: 'Failed to register client' });
    }
  }

  authorize(req: Request, res: Response): void {
    try {
      const { clientId, redirectUri, scopes, state } = req.body;
      const client = this.clients.get(clientId);
      
      if (!client) {
        res.status(400).json({ error: 'Invalid client ID' });
        return;
      }

      if (!client.redirectUris.includes(redirectUri)) {
        res.status(400).json({ error: 'Invalid redirect URI' });
        return;
      }

      const code = this._generateAuthCode(clientId, redirectUri, scopes);
      const authUrl = new URL(redirectUri);
      authUrl.searchParams.set('code', code);
      if (state) authUrl.searchParams.set('state', state);

      res.json({ authorizationUrl: authUrl.toString(), code });
    } catch (error) {
      logger.error('Error in authorize:', error);
      res.status(500).json({ error: 'Authorization failed' });
    }
  }

  token(req: Request, res: Response): void {
    try {
      const { code, clientId, clientSecret, redirectUri } = req.body;
      const authData = this.authorizationCodes.get(code);
      
      if (!authData) {
        res.status(400).json({ error: 'Invalid authorization code' });
        return;
      }

      if (authData.clientId !== clientId) {
        res.status(400).json({ error: 'Client ID mismatch' });
        return;
      }

      const client = this.clients.get(clientId);
      if (!client || !this._verifySecret(clientSecret, client.clientSecret)) {
        res.status(401).json({ error: 'Invalid client credentials' });
        return;
      }

      if (authData.redirectUri !== redirectUri) {
        res.status(400).json({ error: 'Redirect URI mismatch' });
        return;
      }

      if (Date.now() - authData.createdAt > 5 * 60 * 1000) {
        this.authorizationCodes.delete(code);
        res.status(400).json({ error: 'Authorization code expired' });
        return;
      }

      const accessToken = this._generateAccessToken(authData.userId || '', authData.scopes);
      const refreshToken = this._generateRefreshToken(authData.userId || '', authData.scopes);

      this.accessTokens.set(accessToken, {
        userId: authData.userId || '',
        scopes: authData.scopes,
        expiresAt: Date.now() + (60 * 60 * 1000)
      });

      this.refreshTokens.set(refreshToken, {
        userId: authData.userId || '',
        scopes: authData.scopes,
        expiresAt: Date.now() + (60 * 60 * 1000),
        accessToken
      });

      this.authorizationCodes.delete(code);

      res.json({
        access_token: accessToken,
        token_type: 'Bearer',
        expires_in: 3600,
        refresh_token: refreshToken,
        scope: authData.scopes.join(' ')
      });
    } catch (error) {
      logger.error('Error in token exchange:', error);
      res.status(500).json({ error: 'Token exchange failed' });
    }
  }

  private _generateAuthCode(clientId: string, redirectUri: string, scopes: string[]): string {
    const code = crypto.randomBytes(32).toString('hex');
    this.authorizationCodes.set(code, {
      clientId,
      redirectUri,
      scopes,
      userId: null,
      createdAt: Date.now()
    });
    return code;
  }

  private _generateAccessToken(userId: string, scopes: string[]): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private _generateRefreshToken(userId: string, scopes: string[]): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private _hashSecret(secret: string): string {
    return crypto.createHash('sha256').update(secret).digest('hex');
  }

  private _verifySecret(secret: string, hashedSecret: string): boolean {
    return this._hashSecret(secret) === hashedSecret;
  }
}

export default new OAuthService();

