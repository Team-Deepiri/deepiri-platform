/**
 * OAuth 2.0 Service
 * Handles OAuth 2.0 authentication flows
 */
const crypto = require('crypto');
const axios = require('axios');
const logger = require('../utils/logger');

class OAuthService {
  constructor() {
    this.clients = new Map(); // Store OAuth clients
    this.authorizationCodes = new Map(); // Temporary storage for auth codes
    this.accessTokens = new Map(); // Store access tokens
    this.refreshTokens = new Map(); // Store refresh tokens
  }

  /**
   * Register OAuth client
   */
  registerClient(clientId, clientSecret, redirectUris, scopes) {
    const client = {
      clientId,
      clientSecret: this._hashSecret(clientSecret),
      redirectUris,
      scopes,
      createdAt: new Date()
    };
    
    this.clients.set(clientId, client);
    logger.info('OAuth client registered', { clientId });
    return { clientId, clientSecret };
  }

  /**
   * Generate authorization URL
   */
  generateAuthorizationUrl(clientId, redirectUri, scopes, state) {
    const client = this.clients.get(clientId);
    if (!client) {
      throw new Error('Invalid client ID');
    }

    if (!client.redirectUris.includes(redirectUri)) {
      throw new Error('Invalid redirect URI');
    }

    const code = this._generateAuthCode(clientId, redirectUri, scopes);
    const authUrl = new URL(redirectUri);
    authUrl.searchParams.set('code', code);
    authUrl.searchParams.set('state', state);

    return authUrl.toString();
  }

  /**
   * Exchange authorization code for tokens
   */
  exchangeCodeForTokens(code, clientId, clientSecret, redirectUri) {
    const authData = this.authorizationCodes.get(code);
    if (!authData) {
      throw new Error('Invalid authorization code');
    }

    if (authData.clientId !== clientId) {
      throw new Error('Client ID mismatch');
    }

    const client = this.clients.get(clientId);
    if (!client || !this._verifySecret(clientSecret, client.clientSecret)) {
      throw new Error('Invalid client credentials');
    }

    if (authData.redirectUri !== redirectUri) {
      throw new Error('Redirect URI mismatch');
    }

    // Check code expiration (5 minutes)
    if (Date.now() - authData.createdAt > 5 * 60 * 1000) {
      this.authorizationCodes.delete(code);
      throw new Error('Authorization code expired');
    }

    // Generate tokens
    const accessToken = this._generateAccessToken(authData.userId, authData.scopes);
    const refreshToken = this._generateRefreshToken(authData.userId, authData.scopes);

    // Store tokens
    this.accessTokens.set(accessToken, {
      userId: authData.userId,
      scopes: authData.scopes,
      expiresAt: Date.now() + (60 * 60 * 1000) // 1 hour
    });

    this.refreshTokens.set(refreshToken, {
      userId: authData.userId,
      scopes: authData.scopes,
      accessToken
    });

    // Clean up authorization code
    this.authorizationCodes.delete(code);

    return {
      access_token: accessToken,
      token_type: 'Bearer',
      expires_in: 3600,
      refresh_token: refreshToken,
      scope: authData.scopes.join(' ')
    };
  }

  /**
   * Refresh access token
   */
  refreshAccessToken(refreshToken, clientId, clientSecret) {
    const tokenData = this.refreshTokens.get(refreshToken);
    if (!tokenData) {
      throw new Error('Invalid refresh token');
    }

    const client = this.clients.get(clientId);
    if (!client || !this._verifySecret(clientSecret, client.clientSecret)) {
      throw new Error('Invalid client credentials');
    }

    // Generate new access token
    const newAccessToken = this._generateAccessToken(tokenData.userId, tokenData.scopes);

    // Update stored tokens
    this.accessTokens.set(newAccessToken, {
      userId: tokenData.userId,
      scopes: tokenData.scopes,
      expiresAt: Date.now() + (60 * 60 * 1000)
    });

    tokenData.accessToken = newAccessToken;
    this.refreshTokens.set(refreshToken, tokenData);

    return {
      access_token: newAccessToken,
      token_type: 'Bearer',
      expires_in: 3600
    };
  }

  /**
   * Validate access token
   */
  validateAccessToken(accessToken) {
    const tokenData = this.accessTokens.get(accessToken);
    if (!tokenData) {
      return null;
    }

    if (Date.now() > tokenData.expiresAt) {
      this.accessTokens.delete(accessToken);
      return null;
    }

    return {
      userId: tokenData.userId,
      scopes: tokenData.scopes
    };
  }

  /**
   * Revoke token
   */
  revokeToken(token, tokenTypeHint = 'access_token') {
    if (tokenTypeHint === 'access_token') {
      this.accessTokens.delete(token);
    } else if (tokenTypeHint === 'refresh_token') {
      const tokenData = this.refreshTokens.get(token);
      if (tokenData && tokenData.accessToken) {
        this.accessTokens.delete(tokenData.accessToken);
      }
      this.refreshTokens.delete(token);
    }
  }

  _generateAuthCode(clientId, redirectUri, scopes) {
    const code = crypto.randomBytes(32).toString('hex');
    this.authorizationCodes.set(code, {
      clientId,
      redirectUri,
      scopes,
      userId: null, // Set after user authentication
      createdAt: Date.now()
    });
    return code;
  }

  _generateAccessToken(userId, scopes) {
    return crypto.randomBytes(32).toString('hex');
  }

  _generateRefreshToken(userId, scopes) {
    return crypto.randomBytes(32).toString('hex');
  }

  _hashSecret(secret) {
    return crypto.createHash('sha256').update(secret).digest('hex');
  }

  _verifySecret(secret, hashedSecret) {
    return this._hashSecret(secret) === hashedSecret;
  }
}

module.exports = new OAuthService();

