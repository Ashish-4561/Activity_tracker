# 🚀 Render Deployment Guide for DayTrack

This guide walks you through deploying your **DayTrack** backend (and optional web frontend) to [Render](https://render.com).

---

## 📋 Prerequisites
1. A **GitHub** account with this repository pushed.
2. A free **[Render.com](https://render.com)** account.
3. Your **Supabase** credentials (`DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).

---

## Option 1: One-Click Blueprint Deployment (Recommended)

Render uses the [`render.yaml`](file:///c:/Users/ashis/OneDrive/AMBICA/Desktop/activity%20tracker/render.yaml) in the repository root to automatically configure the service.

### Step 1: Push Changes to GitHub
Run the following commands in your terminal:
```bash
git add .
git commit -m "Configure Render deployment and DayTrack branding"
git push origin master
```

### Step 2: Create Blueprint on Render
1. Log in to [dashboard.render.com](https://dashboard.render.com/).
2. Click **New +** in the top right and select **Blueprint**.
3. Connect your GitHub repository (`activity tracker` or `daytrack`).
4. Render will read `render.yaml` and configure the `daytrack-backend` web service.
5. In the **Environment Variables** prompt, fill in:
   - `DATABASE_URL`: Your Supabase PostgreSQL connection string (or leave empty to use local SQLite storage).
   - `SUPABASE_URL`: `https://pdvwyrkttrhfhxgizpoh.supabase.co`
   - `SUPABASE_ANON_KEY`: Your Supabase anon key.
   - `OPENAI_API_KEY`: *(Optional)* Your OpenAI API key if using AI Coach.
6. Click **Apply**.

---

## Option 2: Manual Web Service Deployment

If you prefer to configure manually without Blueprint:

1. In Render Dashboard, click **New +** ➔ **Web Service**.
2. Select your GitHub repository.
3. Configure the settings:
   - **Name**: `daytrack-backend`
   - **Region**: Any (e.g., *Oregon (US West)* or *Frankfurt (EU)*)
   - **Root Directory**: `backend`
   - **Runtime**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`
   - **Plan**: `Free`
4. Add **Environment Variables**:
   | Key | Value |
   |---|---|
   | `NODE_ENV` | `production` |
   | `PORT` | `10000` |
   | `JWT_SECRET` | *(Click "Generate" or enter a secure random 32-char string)* |
   | `JWT_EXPIRATION` | `7d` |
   | `DATABASE_URL` | *(Your Supabase connection string)* |
   | `SUPABASE_URL` | `https://pdvwyrkttrhfhxgizpoh.supabase.co` |
   | `SUPABASE_ANON_KEY` | *(Your Supabase publishable anon key)* |
   | `AI_PROVIDER` | `openai` |
   | `OPENAI_API_KEY` | *(Your OpenAI Key, optional)* |
5. Click **Create Web Service**.

---

## 🔍 Verification & Health Check

Once deployment finishes, Render will provide a public URL like:
`https://daytrack-backend.onrender.com`

1. Open `https://your-service-name.onrender.com/api/health` in your browser.
   - You should see:
   ```json
   { "status": "ok", "timestamp": "2026-10-10T..." }
   ```

2. Update your frontend `.env` file with the live backend URL:
   ```env
   BACKEND_URL=https://your-service-name.onrender.com/api
   ```
