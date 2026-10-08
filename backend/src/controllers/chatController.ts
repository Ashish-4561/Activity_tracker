import { Response } from 'express';
import { AuthRequest } from '../middleware/auth';
import { processUserMessage } from '../ai/aiService';
import { aiGetChatHistory } from '../ai/toolsFunctions';

export async function sendChatMessage(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { message, includeHistory = false } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      res.status(400).json({ error: 'Message is required' });
      return;
    }

    // Get conversation history if needed
    let conversationHistory: any[] = [];
    if (includeHistory) {
      const historyResult = await aiGetChatHistory(req.userId, 10);
      conversationHistory = historyResult.messages || [];
    }

    // Process the message with AI
    const aiResponse = await processUserMessage(
      req.userId,
      message.trim(),
      conversationHistory
    );

    const failed = aiResponse.message.startsWith('OpenAI rejected')
      || aiResponse.message.startsWith('Anthropic rejected')
      || aiResponse.message.startsWith('Unable to reach')
      || aiResponse.message.startsWith('OpenAI rate limit')
      || aiResponse.message.startsWith('Anthropic rate limit');
    res.status(failed ? 502 : 200).json({
      response: aiResponse.message,
      action: aiResponse.action,
    });
  } catch (error: any) {
    console.error('Send chat message error:', error);
    res.status(500).json({ error: 'Failed to process message' });
  }
}

export async function getChatHistory(req: AuthRequest, res: Response): Promise<void> {
  try {
    if (!req.userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { limit = 50 } = req.query;
    const historyResult = await aiGetChatHistory(req.userId, parseInt(limit as string));

    if (historyResult.error) {
      res.status(500).json({ error: historyResult.error });
      return;
    }

    res.json({
      messages: historyResult.messages || [],
    });
  } catch (error: any) {
    console.error('Get chat history error:', error);
    res.status(500).json({ error: 'Failed to get chat history' });
  }
}
