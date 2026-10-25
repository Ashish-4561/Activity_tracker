import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { initializeDatabase, getDatabase } from './config/database';
import authRoutes from './routes/auth';
import activityRoutes from './routes/activities';
import completionRoutes from './routes/completions';
import progressRoutes from './routes/progress';
import chatRoutes from './routes/chat';
import { authMiddleware } from './middleware/auth';

// Prevent transient socket resets (e.g. Supabase pooler idle timeout) from crashing process
process.on('uncaughtException', (err: any) => {
  if (err?.code === 'ECONNRESET' || err?.message?.includes('ECONNRESET')) {
    console.warn('ℹ Handled transient socket reset (ECONNRESET):', err.message || err);
    return;
  }
  console.error('Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason: any) => {
  console.warn('ℹ Handled unhandled promise rejection:', reason);
});

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Allowed CORS origins
const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
  ? process.env.CORS_ALLOWED_ORIGINS.split(',').map((s) => s.trim())
  : [];
if (process.env.FRONTEND_URL) {
  allowedOrigins.push(process.env.FRONTEND_URL.trim());
}

// Middleware
app.use(express.json());
app.use(
  cors({
    origin: (origin, callback) => {
      // Allow non-browser requests (mobile apps, Postman, curl) with no origin header
      if (!origin) return callback(null, true);

      // In development or test, allow local development origins
      if (process.env.NODE_ENV !== 'production') {
        return callback(null, true);
      }

      // In production, check against configured whitelist
      if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new Error(`CORS policy does not allow access from origin ${origin}`));
    },
    credentials: true,
  })
);

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
app.get('/api/health', async (req, res) => {
  try {
    const db = await getDatabase();
    res.json({ status: 'ok', isPostgres: db.isPostgres, timestamp: new Date().toISOString() });
  } catch (e: any) {
    res.status(500).json({ error: e.message });
  }
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

const HOST = process.env.HOST || '0.0.0.0';

app.listen(Number(PORT), HOST, () => {
  console.log(`🚀 Server running at http://${HOST}:${PORT}`);
  console.log(`📊 Health check: http://${HOST}:${PORT}/api/health`);
});
