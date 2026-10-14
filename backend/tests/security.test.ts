import request from 'supertest';
import express from 'express';
import cors from 'cors';
import authRoutes from '../src/routes/auth';
import activityRoutes from '../src/routes/activities';
import { authMiddleware } from '../src/middleware/auth';

const app = express();
app.use(express.json());

// Whitelisted CORS
const allowedOrigins = ['http://localhost:3000', 'https://daytrack.app'];
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error(`CORS blocked for ${origin}`));
    },
    credentials: true,
  })
);

app.use('/api/auth', authRoutes);
app.use('/api/activities', authMiddleware, activityRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

describe('Security and Authorization Integration Tests', () => {
  test('GET /api/health succeeds without credentials', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });

  test('Protected endpoint /api/activities rejects request without token (401)', async () => {
    const res = await request(app).get('/api/activities');
    expect(res.status).toBe(401);
    expect(res.body.error).toBeDefined();
  });

  test('Protected endpoint rejects malformed authorization header (401)', async () => {
    const res = await request(app)
      .get('/api/activities')
      .set('Authorization', 'NotABearerToken 12345');
    expect(res.status).toBe(401);
  });

  test('POST /api/auth/phone/send-otp validates phone length', async () => {
    const res = await request(app)
      .post('/api/auth/phone/send-otp')
      .send({ phone: '123' }); // Too short

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Valid phone number is required/i);
  });

  test('POST /api/auth/signup validates email format', async () => {
    const res = await request(app)
      .post('/api/auth/signup')
      .send({
        name: 'Test User',
        email: 'invalid-email-format',
        password: 'Password123!',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Invalid email format/i);
  });

  test('POST /api/auth/signup validates password length', async () => {
    const res = await request(app)
      .post('/api/auth/signup')
      .send({
        name: 'Test User',
        email: 'test@example.com',
        password: '123', // < 6 chars
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/at least 6 characters/i);
  });
});
