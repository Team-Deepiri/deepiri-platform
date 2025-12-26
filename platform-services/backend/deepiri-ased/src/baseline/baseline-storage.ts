import { BaselineConfig } from '../github/github-types';
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export class BaselineStorage {
  private storageUrl?: string;
  private storageKey?: string;
  private localPath: string;

  constructor(storageUrl?: string, storageKey?: string) {
    this.storageUrl = storageUrl;
    this.storageKey = storageKey;
    this.localPath = path.join(process.cwd(), 'data', 'baseline.json');
  }

  async save(baseline: BaselineConfig): Promise<void> {
    // Encrypt baseline if key is provided
    const data = this.storageKey 
      ? this.encrypt(JSON.stringify(baseline), this.storageKey)
      : JSON.stringify(baseline, null, 2);

    if (this.storageUrl) {
      // Save to external storage
      try {
        await axios.post(this.storageUrl, { data }, {
          headers: {
            'Authorization': `Bearer ${this.storageKey}`,
            'Content-Type': 'application/json',
          },
        });
      } catch (error) {
        console.error('Failed to save baseline to external storage, falling back to local:', error);
        this.saveLocal(data);
      }
    } else {
      // Save locally
      this.saveLocal(data);
    }
  }

  private saveLocal(data: string): void {
    const dir = path.dirname(this.localPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(this.localPath, data, 'utf-8');
  }

  async load(): Promise<BaselineConfig | null> {
    let data: string;

    if (this.storageUrl) {
      try {
        const response = await axios.get(this.storageUrl, {
          headers: {
            'Authorization': `Bearer ${this.storageKey}`,
          },
        });
        data = response.data.data || response.data;
      } catch (error) {
        console.error('Failed to load baseline from external storage, trying local:', error);
        if (fs.existsSync(this.localPath)) {
          data = fs.readFileSync(this.localPath, 'utf-8');
        } else {
          return null;
        }
      }
    } else {
      if (!fs.existsSync(this.localPath)) {
        return null;
      }
      data = fs.readFileSync(this.localPath, 'utf-8');
    }

    // Decrypt if key is provided
    const decrypted = this.storageKey 
      ? this.decrypt(data, this.storageKey)
      : data;

    return JSON.parse(decrypted);
  }

  private encrypt(text: string, key: string): string {
    const algorithm = 'aes-256-cbc';
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(algorithm, Buffer.from(key.substring(0, 32).padEnd(32, '0')), iv);
    let encrypted = cipher.update(text);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    return iv.toString('hex') + ':' + encrypted.toString('hex');
  }

  private decrypt(text: string, key: string): string {
    const algorithm = 'aes-256-cbc';
    const parts = text.split(':');
    const iv = Buffer.from(parts.shift()!, 'hex');
    const encryptedText = Buffer.from(parts.join(':'), 'hex');
    const decipher = crypto.createDecipheriv(algorithm, Buffer.from(key.substring(0, 32).padEnd(32, '0')), iv);
    let decrypted = decipher.update(encryptedText);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return decrypted.toString();
  }
}

