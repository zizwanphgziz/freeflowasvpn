/**
 * terminalSessions.js
 * Module-level session store for concurrent SSH terminals.
 * Lives outside React so sessions survive navigation (navigate away & back).
 *
 * Multiple sessions for the SAME server and DIFFERENT servers are all
 * supported simultaneously — each has its own WebSocket connection.
 */

// sessionId → SessionObject
const sessions = new Map();

// Listeners notified when sessions change
const listeners = new Set();

const notify = () => listeners.forEach((fn) => fn([...sessions.values()]));

/** Create a brand-new session. Returns the sessionId. */
export function createSession({ serverId, serverNickname, serverIp }) {
  const sessionId = `${serverId}-${Date.now()}`;
  sessions.set(sessionId, {
    sessionId,
    serverId,
    serverNickname,
    serverIp,
    status: "disconnected", // disconnected | connecting | authenticating | connected | error
    output: [],
    ws: null,
    createdAt: Date.now(),
  });
  notify();
  return sessionId;
}

/** Retrieve a session by id */
export function getSession(sessionId) {
  return sessions.get(sessionId) || null;
}

/** Get all active sessions as an array */
export function getAllSessions() {
  return [...sessions.values()];
}

/** Patch fields on an existing session (immutable merge) */
export function updateSession(sessionId, patch) {
  const existing = sessions.get(sessionId);
  if (!existing) return;
  sessions.set(sessionId, { ...existing, ...patch });
  notify();
}

/** Append a line to a session's output buffer */
export function appendOutput(sessionId, text, type = "output") {
  const session = sessions.get(sessionId);
  if (!session) return;
  const line = { text, type, ts: new Date().toLocaleTimeString() };
  sessions.set(sessionId, {
    ...session,
    output: [...session.output, line],
  });
  notify();
}

/** Close WS + remove session */
export function destroySession(sessionId) {
  const session = sessions.get(sessionId);
  if (session?.ws) {
    try {
      session.ws.close();
    } catch (_) {}
  }
  sessions.delete(sessionId);
  notify();
}

/** Subscribe to session list changes. Returns an unsubscribe fn. */
export function subscribeToSessions(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
