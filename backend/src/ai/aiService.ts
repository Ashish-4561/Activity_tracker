import axios from 'axios';
import {
  aiCreateActivity,
  aiUpdateActivity,
  aiDeleteActivity,
  aiGetActivities,
  aiCompleteActivity,
  aiUncompleteActivity,
  aiGetDailyProgress,
  aiGetRangeProgress,
  aiSaveChatMessage,
  aiGetChatHistory,
} from './toolsFunctions';

const AI_PROVIDER = (process.env.AI_PROVIDER || 'openai').trim().toLowerCase();

interface AIMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface AIResponse {
  message: string;
  action?: {
    type: string;
    success: boolean;
    data?: any;
  };
}

/**
 * Send a message to the LLM and get a response
 * The LLM will determine which tools to call based on the user's request
 */
export async function processUserMessage(
  userId: string,
  userMessage: string,
  conversationHistory: AIMessage[] = []
): Promise<AIResponse> {
  try {
    // Save user message to chat history
    await aiSaveChatMessage(userId, 'user', userMessage);

    // Get user's activities for context
    const { activities } = await aiGetActivities(userId);

    // Build system prompt
    const end = new Date().toISOString().split('T')[0];
    const startDate = new Date();
    startDate.setUTCDate(startDate.getUTCDate() - 29);
    const progress = await aiGetRangeProgress(userId, startDate.toISOString().split('T')[0], end);
    const systemPrompt = `${buildSystemPrompt(activities || [])}\n\nActual progress for the last 30 days (use only when relevant):\n${JSON.stringify(progress)}`;

    // Build messages for LLM
    const messages = [
      { role: 'system', content: systemPrompt },
      ...conversationHistory.map(message => ({
        role: message.role,
        content: (message as any).content || (message as any).message || '',
      })),
      { role: 'user', content: userMessage },
    ];

    let response: AIResponse = { message: '' };

    if (AI_PROVIDER === 'openai') {
      response = await callOpenAI(userId, messages, userMessage, activities || []);
    } else if (AI_PROVIDER === 'claude') {
      response = await callClaude(userId, messages, userMessage, activities || []);
    } else {
      response = await processIntentWithTools(userId, userMessage, activities || []);
    }

    // Fall back to intelligent intent processing if external LLM fails (quota, rate-limit, auth)
    const isLlmFailure = response.message.startsWith('OpenAI rejected') ||
      response.message.startsWith('Anthropic rejected') ||
      response.message.startsWith('Unable to reach') ||
      response.message.startsWith('OpenAI rate limit') ||
      response.message.startsWith('Anthropic rate limit') ||
      response.message === 'OpenAI API key not configured' ||
      response.message === 'Anthropic API key not configured' ||
      response.message === 'AI provider not configured';

    if (isLlmFailure) {
      console.warn(`[AI Engine] Provider warning (${response.message}). Falling back to internal smart planner.`);
      response = await processIntentWithTools(userId, userMessage, activities || []);
    }

    // Save assistant response
    await aiSaveChatMessage(userId, 'assistant', response.message);

    return response;
  } catch (error: any) {
    console.error('Process user message error:', error);
    try {
      const { activities } = await aiGetActivities(userId);
      return await processIntentWithTools(userId, userMessage, activities || []);
    } catch {
      return {
        message: 'Here is an actionable recommendation: Start by defining one small daily activity you can easily complete in under 15 minutes, track it for 7 days, and build from there.',
      };
    }
  }
}

async function callOpenAI(
  userId: string,
  messages: any[],
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return { message: 'OpenAI API key not configured' };
  }

  try {
    const result = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
        temperature: 0.4,
        messages,
        tools: [{
          type: 'function',
          function: {
            name: 'create_activities',
            description: 'Create one or more activities when the user explicitly asks to turn a routine or plan into tracker activities.',
            parameters: {
              type: 'object',
              properties: {
                activities: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      name: { type: 'string' },
                      frequency_value: { type: 'integer', minimum: 1 },
                      frequency_unit: { type: 'string', enum: ['days', 'weeks', 'months'] },
                      duration_value: { type: 'integer', minimum: 1 },
                      duration_unit: { type: 'string', enum: ['days', 'weeks', 'months'] },
                      group_name: { type: 'string' },
                    },
                    required: ['name', 'frequency_value', 'frequency_unit', 'duration_value', 'duration_unit'],
                  },
                },
              },
              required: ['activities'],
            },
          },
        }],
      },
      { headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' } },
    );
    const assistantMessage = result.data?.choices?.[0]?.message;
    const toolCall = assistantMessage?.tool_calls?.find((call: any) => call.function?.name === 'create_activities');
    if (toolCall) {
      const input = JSON.parse(toolCall.function.arguments || '{}');
      const created: any[] = [];
      for (const activity of input.activities || []) {
        const createdActivity = await aiCreateActivity(
          userId,
          activity.name,
          'custom',
          undefined,
          undefined,
          undefined,
          Number(activity.frequency_value),
          activity.frequency_unit,
          Number(activity.duration_value),
          activity.duration_unit,
        );
        if (createdActivity.success && createdActivity.activity) created.push(createdActivity.activity);
      }
      return {
        message: created.length
          ? `I added ${created.length} activity${created.length === 1 ? '' : 'ies'} from your plan: ${created.map(activity => activity.name).join(', ')}.`
          : 'I could not add the requested plan activities. Please check the details and try again.',
        action: { type: 'create_activities', success: created.length > 0, data: created },
      };
    }
    const content = assistantMessage?.content;
    if (!content) return { message: 'The AI returned an empty response. Please try again.' };
    return { message: content };
  } catch (error: any) {
    console.error('OpenAI error:', error);
    const status = error?.response?.status;
    const providerMessage = error?.response?.data?.error?.message;
    if (status === 401) return { message: 'OpenAI rejected the API key. Revoke the exposed key and add a new valid key in backend/.env.' };
    if (status === 429) return { message: 'OpenAI rate limit or quota exceeded. Check the account billing and usage limits.' };
    if (status === 400) return { message: `OpenAI rejected the request${providerMessage ? `: ${providerMessage}` : '.'}` };
    return { message: `Unable to reach OpenAI${status ? ` (HTTP ${status})` : ''}. Check the backend network connection.` };
  }
}

async function callClaude(
  userId: string,
  messages: any[],
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return { message: 'Claude API key not configured' };
  }

  try {
    const result = await axios.post(
      'https://api.anthropic.com/v1/messages',
      {
        model: process.env.ANTHROPIC_MODEL || 'claude-3-5-haiku-latest',
        max_tokens: 1000,
        system: messages.find(message => message.role === 'system')?.content,
        messages: messages.filter(message => message.role !== 'system'),
      },
      {
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      },
    );
    const content = result.data?.content?.find((item: any) => item.type === 'text')?.text;
    if (!content) return { message: 'The AI returned an empty response. Please try again.' };
    return { message: content };
  } catch (error: any) {
    console.error('Claude error:', error);
    const status = error?.response?.status;
    if (status === 401) return { message: 'Anthropic rejected the API key. Check ANTHROPIC_API_KEY in backend/.env.' };
    if (status === 429) return { message: 'Anthropic rate limit or quota exceeded.' };
    return { message: `Unable to reach Anthropic${status ? ` (HTTP ${status})` : ''}.` };
  }
}

/**
 * Simple intent-based system for processing user requests
 * In production, this would be replaced with actual LLM function calling
 */
async function processIntentWithTools(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const message = userMessage.toLowerCase();

  // 1. Explicit activity management
  if (
    message.includes('add') ||
    message.includes('create') ||
    message.includes('new activity') ||
    message.startsWith('track ')
  ) {
    // If it's a general request like "build me a workout routine and add it", handle creation or routine
    if (!message.includes('workout routine') && !message.includes('study plan')) {
      return handleAddActivity(userId, userMessage, activities);
    }
  }

  if (
    message.includes('delete') ||
    message.includes('remove') ||
    message.includes('remove activity')
  ) {
    return handleDeleteActivity(userId, userMessage, activities);
  }

  if (
    message.includes('rename') ||
    message.includes('change') ||
    message.includes('update')
  ) {
    return handleUpdateActivity(userId, userMessage, activities);
  }

  if (
    message.includes('complete') ||
    message.includes('done') ||
    message.includes('finished') ||
    message.includes('mark as complete')
  ) {
    return handleMarkComplete(userId, userMessage, activities);
  }

  if (
    message.includes('undo') ||
    message.includes('not done') ||
    message.includes('incomplete')
  ) {
    return handleMarkIncomplete(userId, userMessage, activities);
  }

  // 2. Workout & Fitness routines
  if (
    message.includes('workout') ||
    message.includes('gym') ||
    message.includes('exercise') ||
    message.includes('fitness') ||
    message.includes('training') ||
    message.includes('push pull') ||
    message.includes('cardio') ||
    message.includes('lifting')
  ) {
    return handleWorkoutRoutine(userId, userMessage);
  }

  // 3. Study & Learning plans
  if (
    message.includes('study') ||
    message.includes('exam') ||
    message.includes('reading') ||
    message.includes('learn') ||
    message.includes('course') ||
    message.includes('revision') ||
    message.includes('coding') ||
    message.includes('focus')
  ) {
    return handleStudyPlan(userId, userMessage);
  }

  // 4. Routine simplification & Habit building
  if (
    message.includes('easier') ||
    message.includes('simple') ||
    message.includes('overwhelm') ||
    message.includes('morning') ||
    message.includes('night') ||
    message.includes('sleep') ||
    message.includes('habit')
  ) {
    return handleRoutineOptimization(userId, userMessage);
  }

  // 5. Progress queries & Analysis
  if (
    message.includes('progress') ||
    message.includes('how did') ||
    message.includes('completion rate') ||
    message.includes('statistics') ||
    message.includes('analyze') ||
    message.includes('status') ||
    message.includes('summary')
  ) {
    if (message.includes('week') || message.includes('month') || message.includes('history') || message.includes('historical')) {
      return handleHistoricalProgressQuery(userId, userMessage);
    }
    return handleProgressQuery(userId, userMessage, activities);
  }

  if (
    message.includes('help') ||
    message.includes('how do i') ||
    message.includes('what can')
  ) {
    return getHelpMessage();
  }

  if (
    message.includes('suggest') ||
    message.includes('recommendation')
  ) {
    return getSuggestions();
  }

  // 6. Intelligent contextual answer tailored to the user's specific request
  return handleCustomPrompt(userId, userMessage, activities);
}

function handleWorkoutRoutine(userId: string, userMessage: string): AIResponse {
  const isCardio = userMessage.toLowerCase().includes('cardio') || userMessage.toLowerCase().includes('run');
  if (isCardio) {
    return {
      message: `🏃 **Cardio & Endurance Progression Plan**\n\n` +
        `• **Mon**: 20-30 min Zone 2 Easy Jog (aerobic base)\n` +
        `• **Wed**: 15 min Interval Sprints (30s high intensity, 60s walk × 8)\n` +
        `• **Fri**: 30 min Tempo Run / Cycling\n` +
        `• **Sun**: 45 min Low-impact Active Recovery (Long walk or swim)\n\n` +
        `💡 *Recommended activities to add to your tracker:*\n` +
        `1. "🏃 Morning Run" (every 2 days)\n` +
        `2. "💧 Hydration 2.5L" (daily)\n` +
        `3. "🧘 Post-Run Stretching" (daily)\n\n` +
        `Say *"Add Morning Run"* to add it to your tracker immediately!`,
      action: { type: 'suggest_routine', success: true, data: { category: 'cardio' } },
    };
  }

  return {
    message: `🏋️ **Balanced 4-Day Strength & Fitness Routine**\n\n` +
      `• **Day 1: Upper Body Push** (Bench Press, Overhead Press, Incline DB, Triceps - 3 sets × 8-12 reps)\n` +
      `• **Day 2: Lower Body** (Squats, Romanian Deadlifts, Lunges, Calf Raises - 4 sets × 8-10 reps)\n` +
      `• **Day 3: Rest & Mobility** (20 min stretching or light walk)\n` +
      `• **Day 4: Upper Body Pull** (Pull-ups/Lat Pulldown, Barbell Rows, Face Pulls, Biceps - 3 sets × 10-12 reps)\n` +
      `• **Day 5: Full Body & Core** (Planks, Hanging Leg Raises, Kettlebell Swings)\n` +
      `• **Weekend**: Active Recovery\n\n` +
      `💡 *Recommended activities for your tracker:*\n` +
      `1. "🏋️ Gym Workout" (4 days/week)\n` +
      `2. "💧 Drink 3L Water" (daily)\n` +
      `3. "😴 8 Hours Sleep" (daily)\n\n` +
      `Say *"Add Gym Workout as a daily activity"* or *"Add Drink 3L Water"* to add them!`,
    action: { type: 'suggest_routine', success: true, data: { category: 'workout' } },
  };
}

function handleStudyPlan(userId: string, userMessage: string): AIResponse {
  return {
    message: `📚 **High-Efficiency Deep Work & Study Plan**\n\n` +
      `• **Strategy: 50/10 Pomodoro Cycles**\n` +
      `  - Block 1 (Morning): 50 min Deep Focus on hardest concept / problem solving\n` +
      `  - 10 min Screen-free break (hydrate & stretch)\n` +
      `  - Block 2: 50 min Active Recall & Practice testing\n` +
      `• **Evening 20 min**: Review flashcards / summary notes before bed\n` +
      `• **Weekly Checkpoint (Sunday)**: Summarize key learnings & plan topics for next week\n\n` +
      `💡 *Recommended activities for your tracker:*\n` +
      `1. "📚 Study Session (50m)" (daily)\n` +
      `2. "📖 Revision & Notes" (daily)\n` +
      `3. "💻 Coding / Practice Problems" (5 days/week)\n\n` +
      `Say *"Add Study Session"* to add it to your activities now!`,
    action: { type: 'suggest_routine', success: true, data: { category: 'study' } },
  };
}

function handleRoutineOptimization(userId: string, userMessage: string): AIResponse {
  return {
    message: `🌿 **Frictionless Habit & Routine Optimization**\n\n` +
      `When a routine feels heavy, apply the **2-Minute Rule**:\n\n` +
      `1. **Shrink the Entry Barrier**: Instead of "Study 2 hours", commit to "Open textbook & read 1 page". Starting creates momentum.\n` +
      `2. **Habit Stacking**: Anchor each new habit directly after an existing one (e.g. *After I brew morning coffee, I will drink 1 glass of water*).\n` +
      `3. **Visual Triggers**: Place gym clothes or books in plain sight the night before.\n` +
      `4. **Protect Recovery**: Set a hard "screens off" boundary 45 minutes before sleep.\n\n` +
      `Pick just **ONE** anchor activity today and mark it complete once done. Consistency beats intensity!`,
    action: { type: 'optimize_routine', success: true },
  };
}

function handleCustomPrompt(userId: string, userMessage: string, activities: any[]): AIResponse {
  const clean = userMessage.trim();
  const wordCount = clean.split(/\s+/).length;
  const activityNames = activities.map(a => a.name).join(', ');

  return {
    message: `🎯 **Action Plan for: "${clean}"**\n\n` +
      `Here is a structured, realistic approach tailored to your request:\n\n` +
      `1. **Immediate Step (Today)**: Dedicate 15-20 minutes to take the first direct step towards this goal.\n` +
      `2. **Consistency Cadence**: Schedule this for at least 4 days a week at the same time block each day to build automaticity.\n` +
      `3. **Trackable Milestone**: Set a measurable metric for the end of this week to evaluate your momentum.\n\n` +
      (activities.length > 0
        ? `📌 *Current active routines you are balancing: ${activityNames}*\n\n`
        : '') +
      `Would you like me to track a new activity for this? For example: *"Add ${clean.slice(0, 25)}"* as a daily or weekly activity!`,
    action: { type: 'custom_plan', success: true, data: { prompt: clean } },
  };
}

async function handleAddActivity(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  // Extract activity name from the message
  const match = userMessage.match(
    /(?:add|create|new activity)\s+(?:as\s+)?(?:a\s+)?(?:daily\s+|weekly\s+)?activity\s*:?\s*(\w+(?:\s+\w+)*)/i
  ) || userMessage.match(/(?:track|add|create)\s+(\w+(?:\s+\w+)*)/i);

  if (!match || !match[1]) {
    return {
      message: 'I need to know which activity to add. Try: "Add reading as a daily activity"',
    };
  }

  const activityName = match[1].trim();
  const frequency = userMessage.toLowerCase().includes('weekly') ? 'weekly' : 'daily';

  const result = await aiCreateActivity(userId, activityName, frequency);

  if (result.success) {
    return {
      message: `✓ Added "${activityName}" as a ${frequency} activity`,
      action: {
        type: 'create_activity',
        success: true,
        data: result.activity,
      },
    };
  } else {
    return {
      message: result.error || 'Failed to add activity',
      action: {
        type: 'create_activity',
        success: false,
      },
    };
  }
}

async function handleDeleteActivity(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const match = userMessage.match(/(?:delete|remove)\s+(\w+(?:\s+\w+)*)/i);

  if (!match || !match[1]) {
    return {
      message: 'Which activity would you like to remove? Say: "Delete [activity name]"',
    };
  }

  const activityName = match[1].trim().toLowerCase();
  const matchingActivity = activities.find(a => a.name.toLowerCase() === activityName);

  if (!matchingActivity) {
    return {
      message: `I couldn't find an activity called "${activityName}"`,
    };
  }

  const result = await aiDeleteActivity(userId, matchingActivity.id);

  if (result.success) {
    return {
      message: `✓ Deleted "${matchingActivity.name}"`,
      action: {
        type: 'delete_activity',
        success: true,
        data: { activity_id: matchingActivity.id },
      },
    };
  } else {
    return {
      message: result.error || 'Failed to delete activity',
      action: {
        type: 'delete_activity',
        success: false,
      },
    };
  }
}

async function handleUpdateActivity(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  // Extract rename/update intent
  let match = userMessage.match(
    /(?:rename|change)\s+(\w+(?:\s+\w+)*)\s+(?:to|into)\s+(\w+(?:\s+\w+)*)/i
  );

  if (match && match[1] && match[2]) {
    const oldName = match[1].trim().toLowerCase();
    const newName = match[2].trim();
    const activity = activities.find(a => a.name.toLowerCase() === oldName);

    if (!activity) {
      return { message: `I couldn't find an activity called "${oldName}"` };
    }

    const result = await aiUpdateActivity(userId, activity.id, { name: newName });

    if (result.success) {
      return {
        message: `✓ Renamed "${oldName}" to "${newName}"`,
        action: {
          type: 'update_activity',
          success: true,
          data: { activity_id: activity.id },
        },
      };
    } else {
      return {
        message: result.error || 'Failed to update activity',
        action: {
          type: 'update_activity',
          success: false,
        },
      };
    }
  }

  // Change frequency
  match = userMessage.match(
    /(?:make|change)\s+(\w+(?:\s+\w+)*)\s+(?:to\s+)?(?:a\s+)?(daily|weekly)/i
  );

  if (match && match[1] && match[2]) {
    const activityName = match[1].trim().toLowerCase();
    const newFrequency = match[2].toLowerCase();
    const activity = activities.find(a => a.name.toLowerCase() === activityName);

    if (!activity) {
      return { message: `I couldn't find an activity called "${activityName}"` };
    }

    const result = await aiUpdateActivity(userId, activity.id, { frequency: newFrequency });

    if (result.success) {
      return {
        message: `✓ Changed "${activity.name}" to ${newFrequency}`,
        action: {
          type: 'update_activity',
          success: true,
          data: { activity_id: activity.id },
        },
      };
    } else {
      return {
        message: result.error || 'Failed to update activity',
        action: {
          type: 'update_activity',
          success: false,
        },
      };
    }
  }

  return {
    message: 'Tell me what to change. For example: "Rename gym to workout" or "Make reading weekly"',
  };
}

async function handleMarkComplete(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const match = userMessage.match(
    /(?:complete|mark|done|finished)(?:\s+(?:as\s+)?complete)?\s+(\w+(?:\s+\w+)*)/i
  );

  if (!match || !match[1]) {
    return {
      message: 'Which activity did you complete? Say: "I completed [activity name]"',
    };
  }

  const activityName = match[1].trim().toLowerCase();
  const matchingActivities = activities.filter(a => a.name.toLowerCase().includes(activityName));

  if (matchingActivities.length === 0) {
    return { message: `I couldn't find an activity called "${activityName}"` };
  }

  const results = await Promise.all(
    matchingActivities.map(a => aiCompleteActivity(userId, a.id))
  );

  if (results.every(r => r.success)) {
    const names = matchingActivities.map(a => `"${a.name}"`).join(' and ');
    return {
      message: `✓ Marked ${names} as complete`,
      action: {
        type: 'complete_activity',
        success: true,
        data: { activities: matchingActivities.map(a => a.id) },
      },
    };
  } else {
    return {
      message: 'Failed to mark activities as complete',
      action: {
        type: 'complete_activity',
        success: false,
      },
    };
  }
}

async function handleMarkIncomplete(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  const match = userMessage.match(/(?:undo|not done|incomplete)\s+(\w+(?:\s+\w+)*)/i);

  if (!match || !match[1]) {
    return {
      message: 'Which activity should I mark as incomplete?',
    };
  }

  const activityName = match[1].trim().toLowerCase();
  const matchingActivity = activities.find(a => a.name.toLowerCase() === activityName);

  if (!matchingActivity) {
    return { message: `I couldn't find an activity called "${activityName}"` };
  }

  const result = await aiUncompleteActivity(userId, matchingActivity.id);

  if (result.success) {
    return {
      message: `✓ Marked "${matchingActivity.name}" as incomplete`,
      action: {
        type: 'uncomplete_activity',
        success: true,
        data: { activity_id: matchingActivity.id },
      },
    };
  } else {
    return {
      message: result.error || 'Failed to update activity',
      action: {
        type: 'uncomplete_activity',
        success: false,
      },
    };
  }
}

async function handleProgressQuery(
  userId: string,
  userMessage: string,
  activities: any[]
): Promise<AIResponse> {
  try {
    const progress = await aiGetDailyProgress(userId);

    if (!progress.daily_progress) {
      return { message: 'Unable to fetch progress data' };
    }

    const { completed, total, percentage } = progress.daily_progress;

    if (total === 0) {
      return { message: 'You haven\'t added any activities yet' };
    }

    return {
      message: `📊 Today's Progress: ${completed} of ${total} activities completed (${percentage}%)`,
      action: {
        type: 'get_progress',
        success: true,
        data: progress.daily_progress,
      },
    };
  } catch (error) {
    return { message: 'Unable to fetch progress data' };
  }
}

async function handleHistoricalProgressQuery(userId: string, userMessage: string): Promise<AIResponse> {
  const today = new Date();
  const end = today.toISOString().split('T')[0];
  const startDate = new Date(today);
  if (userMessage.toLowerCase().includes('month') || userMessage.toLowerCase().includes('august')) {
    startDate.setDate(1);
  } else {
    startDate.setDate(today.getDate() - 6);
  }
  const start = startDate.toISOString().split('T')[0];
  const progress = await aiGetRangeProgress(userId, start, end);
  if (progress.error) return { message: 'Unable to fetch historical progress' };
  return {
    message: `📈 Progress from ${start} to ${end}: ${progress.completed} of ${progress.total} scheduled activity-days completed (${progress.percentage}%).`,
    action: { type: 'get_historical_progress', success: true, data: progress },
  };
}

function getHelpMessage(): AIResponse {
  return {
    message: `📚 Here's what you can do:\n\n• **Add activities**: "Add reading as a daily activity"\n• **Remove activities**: "Delete meditation"\n• **Rename activities**: "Rename gym to workout"\n• **Mark complete**: "I completed coding"\n• **Mark incomplete**: "Undo reading"\n• **Check progress**: "How did I do today?"\n• **Suggestions**: "What should I track?"\n\nJust tell me what you need!`,
  };
}

function getSuggestions(): AIResponse {
  return {
    message: `💡 Here are some popular activities to track:\n\n📚 Study\n💻 Coding\n🏃 Exercise\n📖 Reading\n🧘 Meditation\n💪 Gym\n🎵 Music\n✍️ Writing\n\nWould you like me to add any of these?`,
  };
}

function buildSystemPrompt(activities: any[]): string {
  const activityList = activities.length > 0
    ? activities.map(a => `- ${a.name} (every ${a.frequency_value || 1} ${a.frequency_unit || (a.frequency === 'weekly' ? 'weeks' : 'days')}, from ${a.start_date || 'today'})`).join('\n')
    : 'None yet';

  return `You are a helpful personal activity tracking assistant. You help users manage their daily activities and track their progress.

Current user activities:
${activityList}

You have access to the following commands:
- Add activities
- Remove activities
- Update activities (rename, change frequency)
- Mark activities as complete
- Mark activities as incomplete
- Check daily/weekly/monthly progress
- View statistics and streaks

Keep responses natural, specific to the user's latest message, and useful in follow-up turns. Use the conversation history to resolve references such as "that plan" or "make it easier".
Never make up progress statistics, activity names, or completed work. If the user asks for progress, explain that the backend must provide the data before stating a number.
For study, workout, sleep, or other routine requests, create a practical structured plan with clear steps and suggested frequency/duration. Do not return the same generic advice for unrelated requests.`;
}
