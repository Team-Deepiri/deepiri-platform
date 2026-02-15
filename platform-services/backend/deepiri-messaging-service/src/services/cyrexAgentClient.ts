import axios, { AxiosInstance, AxiosError } from 'axios';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

/**
 * Cyrex Agent Client
 * HTTP client for communicating with diri-cyrex agent endpoints
 * 
 * Handles:
 * - Agent initialization
 * - Agent message sending (streaming and non-streaming)
 * - Conversation history retrieval
 * 
 * All agent logic is in cyrex - this just orchestrates the calls
 */
class CyrexAgentClient {
  private client: AxiosInstance;
  private baseUrl: string;

  constructor() {
    this.baseUrl = config.cyrex.baseUrl;
    
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 120000, // 2 minutes for agent responses
      headers: {
        'Content-Type': 'application/json',
        ...(config.cyrex.apiKey ? { 'x-api-key': config.cyrex.apiKey } : {}),
      },
    });

    // Add retry logic for transient failures
    this.client.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const config = error.config as any;
        
        // Retry on 5xx errors or network errors
        if (
          (!error.response || (error.response.status >= 500 && error.response.status < 600)) &&
          (!config || !config.__retryCount || config.__retryCount < 3)
        ) {
          config.__retryCount = (config.__retryCount || 0) + 1;
          const delay = Math.pow(2, config.__retryCount) * 1000; // Exponential backoff
          
          logger.warn(`Retrying cyrex agent request (attempt ${config.__retryCount})`, {
            url: config.url,
            delay,
          });
          
          await new Promise((resolve) => setTimeout(resolve, delay));
          return this.client(config);
        }
        
        return Promise.reject(error);
      }
    );
  }

  /**
   * Initialize agent instance in cyrex
   * Calls: POST /api/agent/initialize
   */
  async initializeAgent(agentConfig: {
    name: string;
    agentType: string;
    model: string;
    temperature?: number;
    maxTokens?: number;
    tools?: string[];
  }): Promise<{ instanceId: string; status: string }> {
    try {
      logger.info('Initializing agent in cyrex', { name: agentConfig.name });
      
      const response = await this.client.post('/api/agent/initialize', {
        name: agentConfig.name,
        agent_type: agentConfig.agentType,
        model: agentConfig.model,
        temperature: agentConfig.temperature,
        max_tokens: agentConfig.maxTokens,
        tools: agentConfig.tools,
      });

      return {
        instanceId: response.data.instance_id,
        status: response.data.status || 'idle',
      };
    } catch (error: any) {
      logger.error('Agent initialization failed', {
        error: error.message,
        status: error.response?.status,
        data: error.response?.data,
      });
      throw new Error(`Agent initialization failed: ${error.response?.data?.detail || error.message}`);
    }
  }

  /**
   * Send message to agent (non-streaming)
   * Calls: POST /api/agent/invoke
   */
  async sendMessage(instanceId: string, message: string, chatRoomId?: string): Promise<any> {
    try {
      logger.info('Sending message to agent', { instanceId, messageLength: message.length, chatRoomId });
      
      const payload: any = {
        instance_id: instanceId,
        input: message,
        stream: false,
      };
      
      // Include chat_room_id in context so cyrex can send response back to messaging service
      if (chatRoomId) {
        payload.context = {
          chat_room_id: chatRoomId,
        };
      }
      
      const response = await this.client.post('/api/agent/invoke', payload);

      return response.data;
    } catch (error: any) {
      logger.error('Agent message failed', {
        instanceId,
        error: error.message,
        status: error.response?.status,
      });
      throw error;
    }
  }

  /**
   * Send message to agent (streaming)
   * Returns ReadableStream for forwarding to WebSocket
   * Calls: POST /api/agent/invoke (with stream: true)
   */
  async sendMessageStream(instanceId: string, message: string, chatRoomId?: string): Promise<NodeJS.ReadableStream | null> {
    try {
      logger.info('Sending streaming message to agent', { instanceId, chatRoomId });
      
      const payload: any = {
        instance_id: instanceId,
        input: message,
        stream: true,
      };
      
      // Include chat_room_id in context so cyrex can send response back to messaging service
      if (chatRoomId) {
        payload.context = {
          chat_room_id: chatRoomId,
        };
      }
      
      const response = await this.client.post(
        '/api/agent/invoke',
        payload,
        {
          responseType: 'stream',
        }
      );

      return response.data;
    } catch (error: any) {
      logger.error('Agent streaming failed', {
        instanceId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get agent conversation history
   * Calls: GET /api/agent/{instanceId}/conversation
   */
  async getConversation(instanceId: string): Promise<any> {
    try {
      const response = await this.client.get(`/api/agent/${instanceId}/conversation`);
      return response.data;
    } catch (error: any) {
      logger.error('Failed to get conversation', {
        instanceId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get all agent instances
   * Calls: GET /api/agent/instances
   */
  async getAgentInstances(): Promise<any[]> {
    try {
      const response = await this.client.get('/api/agent/instances');
      return response.data.instances || [];
    } catch (error: any) {
      logger.error('Failed to get agent instances', { error: error.message });
      return [];
    }
  }
}

export const cyrexAgentClient = new CyrexAgentClient();

