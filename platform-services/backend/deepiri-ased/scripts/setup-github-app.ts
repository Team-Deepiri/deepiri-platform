import dotenv from 'dotenv';
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import { createLogger } from '@deepiri/shared-utils';

dotenv.config();

const logger = createLogger('setup-github-app');

interface GitHubAppConfig {
  name: string;
  description: string;
  url: string;
  callback_url: string;
  webhook_url: string;
  webhook_secret: string;
  permissions: {
    metadata: string;
    contents: string;
    administration: string;
    organization_administration: string;
    members: string;
  };
  events: string[];
  installation_target: 'organization';
  installation_target_id: string;
}

async function createGitHubApp(orgOwnerToken: string, org: string): Promise<{
  appId: string;
  installationId: string;
  privateKey: string;
  clientId: string;
  clientSecret: string;
}> {
  logger.info('Creating GitHub App...');

  // Generate webhook secret
  const webhookSecret = require('crypto').randomBytes(32).toString('hex');

  const appConfig: GitHubAppConfig = {
    name: `deepiri-ased-${Date.now()}`,
    description: 'Deepiri Autonomous Sovereignty Enforcement Detonator - Organization Security Monitoring',
    url: 'https://github.com/Team-Deepiri',
    callback_url: 'https://github.com/apps/deepiri-ased/callback',
    webhook_url: process.env.ASED_WEBHOOK_URL || 'https://your-domain.com/webhook/github',
    webhook_secret: webhookSecret,
    permissions: {
      metadata: 'read-only',
      contents: 'read-write',
      administration: 'read-write',
      organization_administration: 'read',
      members: 'read-only',
    },
    events: [
      'repository',
      'organization',
      'member',
      'team',
      'push',
      'workflow_run',
    ],
    installation_target: 'organization',
    installation_target_id: org,
  };

  try {
    // Note: GitHub Apps must be created via web UI or using a different method
    // This is a placeholder - actual implementation requires:
    // 1. Manual app creation via GitHub UI, OR
    // 2. Using GitHub's app creation API (requires special permissions)
    
    logger.warn('GitHub App creation via API requires special permissions.');
    logger.info('Please create the app manually:');
    logger.info('1. Go to: https://github.com/organizations/' + org + '/settings/apps');
    logger.info('2. Click "New GitHub App"');
    logger.info('3. Use the configuration below:');
    logger.info(JSON.stringify(appConfig, null, 2));
    
    // For now, we'll use a simpler approach: generate installation token from existing app
    // Or use personal access token as fallback
    
    throw new Error('GitHub App creation requires manual setup. See instructions above.');
  } catch (error: any) {
    logger.error('Failed to create GitHub App:', error.message);
    throw error;
  }
}

async function generateInstallationToken(
  appId: string,
  installationId: string,
  privateKey: string
): Promise<string> {
  const jwt = require('jsonwebtoken');
  
  // Generate JWT
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iat: now - 60,
    exp: now + 600, // 10 minutes
    iss: appId,
  };
  
  const token = jwt.sign(payload, privateKey, { algorithm: 'RS256' });
  
  // Get installation token
  const response = await axios.post(
    `https://api.github.com/app/installations/${installationId}/access_tokens`,
    {},
    {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github.v3+json',
      },
    }
  );
  
  return response.data.token;
}

async function saveToK8sSecret(config: {
  appId: string;
  installationId: string;
  privateKey: string;
  org: string;
}): Promise<void> {
  const secretPath = path.join(process.cwd(), '../../ops/k8s/secrets/ased-secret.yaml');
  const secretDir = path.dirname(secretPath);
  
  if (!fs.existsSync(secretDir)) {
    fs.mkdirSync(secretDir, { recursive: true });
  }
  
  const secretYaml = `apiVersion: v1
kind: Secret
metadata:
  name: deepiri-ased-secret
  namespace: default
type: Opaque
stringData:
  GITHUB_APP_ID: "${config.appId}"
  GITHUB_INSTALLATION_ID: "${config.installationId}"
  GITHUB_APP_PRIVATE_KEY: |
${config.privateKey.split('\n').map((line: string) => '    ' + line).join('\n')}
  GITHUB_ORG: "${config.org}"
  # Auto-discovered repos (comma-separated, will be populated on first run)
  CRITICAL_REPOS: ""
`;

  fs.writeFileSync(secretPath, secretYaml, 'utf-8');
  logger.info(`Secret saved to: ${secretPath}`);
}

async function main() {
  try {
    const org = process.env.GITHUB_ORG || 'Team-Deepiri';
    const orgOwnerToken = process.env.GITHUB_ORG_OWNER_TOKEN;
    
    if (!orgOwnerToken) {
      logger.error('GITHUB_ORG_OWNER_TOKEN not set!');
      logger.info('This token is only needed for one-time setup.');
      logger.info('Get it from: https://github.com/settings/tokens');
      logger.info('Required scopes: admin:org, repo');
      process.exit(1);
    }
    
    logger.info(`Setting up GitHub App for organization: ${org}`);
    
    // For now, we'll provide instructions for manual setup
    // and create a template secret file
    logger.info('');
    logger.info('=== Manual GitHub App Setup Required ===');
    logger.info('');
    logger.info('1. Go to: https://github.com/organizations/' + org + '/settings/apps');
    logger.info('2. Click "New GitHub App"');
    logger.info('3. Configure:');
    logger.info('   - Name: deepiri-ased');
    logger.info('   - Homepage: https://github.com/Team-Deepiri');
    logger.info('   - Webhook URL: (your webhook endpoint, optional)');
    logger.info('   - Permissions:');
    logger.info('     * Repository permissions:');
    logger.info('       - Contents: Read & Write');
    logger.info('       - Metadata: Read-only');
    logger.info('       - Administration: Read & Write');
    logger.info('     * Organization permissions:');
    logger.info('       - Members: Read-only');
    logger.info('       - Administration: Read');
    logger.info('4. Install on: All repositories (or select specific ones)');
    logger.info('5. After installation, you will get:');
    logger.info('   - App ID');
    logger.info('   - Installation ID');
    logger.info('   - Private Key (download .pem file)');
    logger.info('');
    logger.info('Then run this script again with:');
    logger.info('  GITHUB_APP_ID=xxx GITHUB_INSTALLATION_ID=xxx GITHUB_APP_PRIVATE_KEY="$(cat key.pem)" npm run setup-github-app');
    logger.info('');
    
    // If app credentials are provided, save them
    const appId = process.env.GITHUB_APP_ID;
    const installationId = process.env.GITHUB_INSTALLATION_ID;
    const privateKey = process.env.GITHUB_APP_PRIVATE_KEY;
    
    if (appId && installationId && privateKey) {
      logger.info('App credentials provided, saving to k8s secret...');
      await saveToK8sSecret({
        appId,
        installationId,
        privateKey,
        org,
      });
      logger.info('Setup complete!');
      logger.info('The service will automatically use these credentials.');
    } else {
      logger.info('App credentials not provided. Please follow manual setup above.');
      process.exit(0);
    }
  } catch (error: any) {
    logger.error('Setup failed:', error);
    process.exit(1);
  }
}

main();

