import { Router } from 'express';
import { sendChatMessage, getChatHistory } from '../controllers/chatController';

const router = Router();

router.post('/message', sendChatMessage);
router.get('/history', getChatHistory);

export default router;
