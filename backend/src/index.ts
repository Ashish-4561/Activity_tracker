import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { initializeDatabase } from './config/database';
import authRoutes from './routes/auth';
import activityRoutes from './routes/activities';
import completionRoutes from './routes/completions';
import progressRoutes from './routes/progress';
import chatRoutes from './routes/chat';
import { authMiddleware } from './middleware/auth';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(express.json());
app.use(cors({
  origin: true,
  credentials: true,
}));

// Initialize database on startup
(async () => {
  try {
    await initializeDatabase();
    console.log('✓ Database initialized successfully');
  } catch (error) {
    console.error('✗ Database initialization failed:', error);
    process.exit(1);
  }
})();

// Public routes
app.use('/api/auth', authRoutes);

// Protected routes
app.use('/api/activities', authMiddleware, activityRoutes);
app.use('/api/completions', authMiddleware, completionRoutes);
app.use('/api/progress', authMiddleware, progressRoutes);
app.use('/api/chat', authMiddleware, chatRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
});
