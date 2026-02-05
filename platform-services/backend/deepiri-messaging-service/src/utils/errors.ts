export class MessagingError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code?: string
  ) {
    super(message);
    this.name = 'MessagingError';
  }
}

export class ChatRoomNotFoundError extends MessagingError {
  constructor(chatRoomId: string) {
    super(`Chat room not found: ${chatRoomId}`, 404, 'CHAT_ROOM_NOT_FOUND');
    this.name = 'ChatRoomNotFoundError';
  }
}

export class MessageNotFoundError extends MessagingError {
  constructor(messageId: string) {
    super(`Message not found: ${messageId}`, 404, 'MESSAGE_NOT_FOUND');
    this.name = 'MessageNotFoundError';
  }
}

export class UnauthorizedError extends MessagingError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
    this.name = 'UnauthorizedError';
  }
}

export class ValidationError extends MessagingError {
  constructor(message: string) {
    super(message, 400, 'VALIDATION_ERROR');
    this.name = 'ValidationError';
  }
}

