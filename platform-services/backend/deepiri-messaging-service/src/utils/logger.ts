import { createLogger } from '@team-deepiri/shared-utils';
import type { Logger } from 'winston';

export const logger: Logger = createLogger('deepiri-messaging-service');

export default logger;