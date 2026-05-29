import { useState, useEffect, useRef, useCallback } from "react";
import {
  View,
  Text,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Modal,
  Alert,
  ActivityIndicator,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import { useTheme } from "@/utils/ThemeContext";
import { osData } from "@/data/osData";
import {
  createSession,
  getSession,
  updateSession,
  appendOutput,
  destroySession,
  getAllSessions,
  subscribeToSessions,
} from "@/utils/terminalSessions";

const BACKEND_URL_KEY = "@freeflow_backend_url";
const STORAGE_KEY = "@freeflow_vps_list";

// WebSocket objects live outside React — survive re-renders & navigation
const wsMap = new Map();

export default function TerminalScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const params = useLocalSearchParams();
  const { theme } = useTheme();
  const { BG, CARD, BORDER, CYAN, TEAL, TEXT, MUTED, GREEN, ORANGE, RED } =
    theme;

  const [sessionId, setSessionId] = useState(params.sessionId || null);
  const [session, setSession] = useState(null);
  const [allSessions, setAllSessions] = useState(getAllSessions());

  const [input, setInput] = useState("");
  const [showRebuildModal, setShowRebuildModal] = useState(false);
  const [showSessionsModal, setShowSessionsModal] = useState(false);
  const [showSetupGuide, setShowSetupGuide] = useState(false);
  const [backendUrl, setBackendUrl] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("linux");
  const [selectedOS, setSelectedOS] = useState(null);
  const [selectedVersion, setSelectedVersion] = useState(null);
  const scrollRef = useRef(null);

  // Keep local snapshot in sync with session store
  useEffect(() => {
    const unsub = subscribeToSessions((sessions) => {
      setAllSessions(sessions);
      if (sessionId) {
        const s = getSession(sessionId);
        if (s) setSession({ ...s });
      }
    });
    return unsub;
  }, [sessionId]);

  useEffect(() => {
    bootstrap();
    // Sessions survive unmount intentionally — do NOT close WS here
  }, []);

  const bootstrap = async () => {
    try {
      const url = await AsyncStorage.getItem(BACKEND_URL_KEY);
      if (!url) {
        setShowSetupGuide(true);
        return;
      }
      setBackendUrl(url);

      const raw = await AsyncStorage.getItem(STORAGE_KEY);
      const servers = raw ? JSON.parse(raw) : [];
      const server = servers.find((s) => s.id === params.serverId);
      if (!server) {
        Alert.alert("Error", "Server not found");
        router.back();
        return;
      }

      // Reuse an existing session for this serverId if one was passed, or create new
      let sid = params.sessionId;
      if (!sid || !getSession(sid)) {
        sid = createSession({
          serverId: server.id,
          serverNickname: server.nickname,
          serverIp: server.ip,
        });
      }
      setSessionId(sid);
      setSession(getSession(sid));

      const s = getSession(sid);
      // Auto-connect if the session is in a state where the WS isn't live
      if (s && (s.status === "disconnected" || s.status === "error")) {
        connectSSH(sid, server, url);
      }
    } catch (e) {
      console.error("bootstrap error", e);
      Alert.alert("Error", "Failed to load server details");
    }
  };

  const connectSSH = (sid, server, wsUrl) => {
    updateSession(sid, { status: "connecting" });
    appendOutput(sid, "🔌 Connecting to backend...", "status");

    let endpoint = wsUrl.replace(/^http/, "ws");
    if (!endpoint.endsWith("/")) endpoint += "/";
    endpoint += "ws/ssh";

    const ws = new WebSocket(endpoint);
    wsMap.set(sid, ws);

    ws.onopen = () => {
      updateSession(sid, { status: "authenticating" });
      appendOutput(sid, "✓ Backend connected", "success");
      appendOutput(sid, `🔐 Authenticating to ${server.ip}...`, "status");
      ws.send(
        JSON.stringify({
          host: server.ip,
          port: server.sshPort || 22,
          username: server.sshUsername || "root",
          password: server.passwordHint || "",
          privateKey: "",
        }),
      );
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === "connected") {
          updateSession(sid, { status: "connected" });
          appendOutput(
            sid,
            "✓ Terminal ready! Type commands or tap 🚀 to rebuild.",
            "success",
          );
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        } else if (msg.type === "output") {
          appendOutput(sid, msg.data, "output");
        } else if (msg.type === "status") {
          appendOutput(sid, msg.data, "status");
        } else if (msg.type === "error") {
          updateSession(sid, { status: "error" });
          appendOutput(sid, `❌ ${msg.data}`, "error");
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        }
      } catch (_) {}
    };

    ws.onerror = () => {
      updateSession(sid, { status: "error" });
      appendOutput(
        sid,
        "❌ WebSocket error — check backend URL & network",
        "error",
      );
    };

    ws.onclose = () => {
      updateSession(sid, { status: "disconnected" });
      appendOutput(sid, "🔌 Connection closed", "status");
      wsMap.delete(sid);
    };

    updateSession(sid, { ws });
  };

  const sendCommand = useCallback(() => {
    if (!input.trim() || !sessionId) return;
    const ws = wsMap.get(sessionId);
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    appendOutput(sessionId, `$ ${input}`, "input");
    ws.send(JSON.stringify({ type: "input", data: input + "\n" }));
    setInput("");
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, [input, sessionId]);

  const executeRebuild = () => {
    if (!selectedOS || !selectedVersion) {
      Alert.alert("Select OS", "Choose an OS and version first");
      return;
    }
    Alert.alert(
      "⚠️ Confirm OS Rebuild",
      `This will WIPE the current OS and install ${selectedOS.name} ${selectedVersion.version}.\n\nMay take 5-15 minutes. Continue?`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Rebuild Now",
          style: "destructive",
          onPress: () => {
            setShowRebuildModal(false);
            appendOutput(
              sessionId,
              `\n🚀 STARTING OS REBUILD — ${selectedOS.name} ${selectedVersion.version}`,
              "rebuild",
            );
            appendOutput(
              sessionId,
              "⏳ Do NOT close this screen...\n",
              "rebuild",
            );
            const ws = wsMap.get(sessionId);
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(
                JSON.stringify({
                  type: "execute",
                  data: selectedVersion.script,
                }),
              );
            }
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          },
        },
      ],
    );
  };

  const switchToSession = (sid) => {
    setSessionId(sid);
    setSession(getSession(sid));
    setShowSessionsModal(false);
  };

  const closeSession = (sid) => {
    const ws = wsMap.get(sid);
    if (ws) {
      try {
        ws.close();
      } catch (_) {}
    }
    wsMap.delete(sid);
    destroySession(sid);
    if (sid === sessionId) {
      const remaining = getAllSessions();
      if (remaining.length > 0) {
        switchToSession(remaining[0].sessionId);
      } else {
        router.back();
      }
    }
  };

  const getStatusConfig = (st) => {
    switch (st) {
      case "connected":
        return { emoji: "🟢", color: GREEN, label: "Connected" };
      case "connecting":
        return { emoji: "🟡", color: ORANGE, label: "Connecting..." };
      case "authenticating":
        return { emoji: "🟡", color: ORANGE, label: "Authenticating..." };
      case "error":
        return { emoji: "🔴", color: RED, label: "Error" };
      default:
        return { emoji: "⚫", color: MUTED, label: "Disconnected" };
    }
  };

  // Auto-scroll when output grows
  useEffect(() => {
    if ((session?.output?.length || 0) > 0) {
      setTimeout(() => scrollRef.current?.scrollToEnd({ animated: true }), 80);
    }
  }, [session?.output?.length]);

  const output = session?.output || [];
  const status = session?.status || "disconnected";
  const statusCfg = getStatusConfig(status);
  const activeCount = allSessions.length;

  // ── Setup guide ──
  if (showSetupGuide) {
    return (
      <View style={{ flex: 1, backgroundColor: BG }}>
        <StatusBar style="light" />
        <View
          style={{
            paddingTop: insets.top + 16,
            paddingHorizontal: 20,
            paddingBottom: 16,
            borderBottomWidth: 1,
            borderBottomColor: BORDER,
          }}
        >
          <TouchableOpacity onPress={() => router.back()}>
            <Text style={{ color: CYAN, fontSize: 16, fontWeight: "700" }}>
              ← Back
            </Text>
          </TouchableOpacity>
        </View>
        <ScrollView
          contentContainerStyle={{
            padding: 20,
            paddingBottom: insets.bottom + 40,
          }}
        >
          <Text style={{ fontSize: 48, textAlign: "center", marginBottom: 16 }}>
            🚀
          </Text>
          <Text
            style={{
              color: TEXT,
              fontSize: 22,
              fontWeight: "800",
              textAlign: "center",
              marginBottom: 12,
            }}
          >
            Backend Setup Required
          </Text>
          <Text
            style={{
              color: MUTED,
              fontSize: 14,
              textAlign: "center",
              lineHeight: 20,
              marginBottom: 28,
            }}
          >
            SSH Terminal & One-Click Rebuild require a self-hosted backend
            running on any VPS.
          </Text>
          <View
            style={{
              backgroundColor: CARD,
              borderRadius: 14,
              borderWidth: 1,
              borderColor: BORDER,
              padding: 16,
              marginBottom: 20,
            }}
          >
            <Text
              style={{
                color: TEXT,
                fontSize: 15,
                fontWeight: "700",
                marginBottom: 10,
              }}
            >
              📋 Setup Steps
            </Text>
            <Text
              style={{
                color: MUTED,
                fontSize: 13,
                lineHeight: 20,
                marginBottom: 12,
              }}
            >
              1. SSH into any VPS{"\n"}2. Run the one-liner below{"\n"}3.
              Backend starts on port 8000{"\n"}4. Enter the URL below
            </Text>
            <View
              style={{
                backgroundColor: BG,
                borderRadius: 8,
                padding: 12,
                borderWidth: 1,
                borderColor: BORDER,
              }}
            >
              <Text
                style={{
                  color: CYAN,
                  fontFamily: "monospace",
                  fontSize: 11,
                  lineHeight: 16,
                }}
              >
                curl -fsSL https://raw.githubusercontent.com/{"\n"}
                zizwanphgziz/freeflowoneliner{"\n"}
                rebuildvps/devin/initial-setup/{"\n"}setup.sh | bash
              </Text>
            </View>
          </View>
          <Text
            style={{
              color: TEXT,
              fontSize: 13,
              fontWeight: "700",
              marginBottom: 8,
            }}
          >
            Backend WebSocket URL
          </Text>
          <TextInput
            placeholder="ws://YOUR_VPS_IP:8000"
            placeholderTextColor={MUTED}
            value={backendUrl}
            onChangeText={setBackendUrl}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            style={{
              backgroundColor: CARD,
              borderRadius: 10,
              borderWidth: 1,
              borderColor: BORDER,
              color: TEXT,
              fontSize: 14,
              fontFamily: "monospace",
              paddingHorizontal: 14,
              paddingVertical: 12,
              marginBottom: 24,
            }}
          />
          <TouchableOpacity
            onPress={async () => {
              if (!backendUrl.trim()) {
                Alert.alert("Required", "Enter backend URL first");
                return;
              }
              await AsyncStorage.setItem(BACKEND_URL_KEY, backendUrl.trim());
              setShowSetupGuide(false);
              bootstrap();
            }}
            style={{
              backgroundColor: CYAN,
              borderRadius: 12,
              paddingVertical: 16,
              alignItems: "center",
            }}
          >
            <Text style={{ color: "#000F1A", fontWeight: "800", fontSize: 15 }}>
              Save & Connect
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </View>
    );
  }

  // ── Main terminal ──
  return (
    <View style={{ flex: 1, backgroundColor: "#000F1A" }}>
      <StatusBar style="light" />

      {/* Header */}
      <View
        style={{
          paddingTop: insets.top + 10,
          paddingHorizontal: 14,
          paddingBottom: 10,
          backgroundColor: "#001020",
          borderBottomWidth: 1,
          borderBottomColor: "#002040",
          flexDirection: "row",
          alignItems: "center",
          gap: 10,
        }}
      >
        <TouchableOpacity onPress={() => router.back()}>
          <Text style={{ color: CYAN, fontSize: 15, fontWeight: "700" }}>
            ←
          </Text>
        </TouchableOpacity>

        <View style={{ flex: 1 }}>
          <Text
            style={{ color: "#FFF", fontSize: 14, fontWeight: "800" }}
            numberOfLines={1}
          >
            {session?.serverNickname || "Terminal"}
          </Text>
          <View
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: 5,
              marginTop: 1,
            }}
          >
            <Text style={{ fontSize: 9 }}>{statusCfg.emoji}</Text>
            <Text
              style={{
                color: statusCfg.color,
                fontSize: 10,
                fontWeight: "700",
              }}
            >
              {statusCfg.label}
            </Text>
            <Text style={{ color: "#2A4060", fontSize: 10 }}>·</Text>
            <Text
              style={{
                color: "#2A6080",
                fontSize: 10,
                fontFamily: "monospace",
              }}
            >
              {session?.serverIp}
            </Text>
          </View>
        </View>

        {/* Sessions switcher */}
        <TouchableOpacity
          onPress={() => setShowSessionsModal(true)}
          style={{
            backgroundColor: "#001A30",
            borderRadius: 8,
            paddingHorizontal: 10,
            paddingVertical: 6,
            borderWidth: 1,
            borderColor: activeCount > 1 ? CYAN + "80" : "#003050",
            flexDirection: "row",
            alignItems: "center",
            gap: 5,
          }}
        >
          <Text style={{ color: CYAN, fontSize: 12, fontWeight: "800" }}>
            ⊞ {activeCount}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={async () => {
            if (!sessionId) return;
            const raw = await AsyncStorage.getItem(STORAGE_KEY);
            const all = raw ? JSON.parse(raw) : [];
            const s = getSession(sessionId);
            if (!s) return;
            const server = all.find((x) => x.id === s.serverId);
            if (!server) return;
            const url = await AsyncStorage.getItem(BACKEND_URL_KEY);
            if (!url) return;
            // Close existing socket first
            const existing = wsMap.get(sessionId);
            if (existing) {
              try { existing.close(); } catch (_) {}
              wsMap.delete(sessionId);
            }
            updateSession(sessionId, { status: "disconnected" });
            connectSSH(sessionId, server, url);
          }}
          style={{
            backgroundColor: "#001530",
            borderRadius: 8,
            paddingHorizontal: 10,
            paddingVertical: 6,
            borderWidth: 1,
            borderColor: CYAN,
          }}
        >
          <Text style={{ color: CYAN, fontSize: 11, fontWeight: "700" }}>
            ↻ Reconnect
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={() => closeSession(sessionId)}
          style={{
            backgroundColor: "#2A0010",
            borderRadius: 8,
            paddingHorizontal: 10,
            paddingVertical: 6,
            borderWidth: 1,
            borderColor: RED,
          }}
        >
          <Text style={{ color: RED, fontSize: 11, fontWeight: "700" }}>
            ✕ Close
          </Text>
        </TouchableOpacity>
      </View>

      {/* Terminal output */}
      <ScrollView
        ref={scrollRef}
        style={{ flex: 1 }}
        contentContainerStyle={{ padding: 12, paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
      >
        {output.length === 0 && (
          <Text
            style={{ color: "#1A3A5A", fontFamily: "monospace", fontSize: 12 }}
          >
            Waiting for connection...
          </Text>
        )}
        {output.map((line, idx) => {
          const colorMap = {
            output: "#00FF88",
            status: "#00D9FF",
            success: "#00FF88",
            error: "#FF4444",
            input: "#FFAA00",
            rebuild: "#FF00FF",
          };
          return (
            <Text
              key={idx}
              style={{
                color: colorMap[line.type] || "#00FF88",
                fontFamily: "monospace",
                fontSize: 12,
                lineHeight: 18,
                marginBottom: 2,
              }}
            >
              {line.text}
            </Text>
          );
        })}
        {(status === "connecting" || status === "authenticating") && (
          <ActivityIndicator
            color={CYAN}
            size="small"
            style={{ marginTop: 10 }}
          />
        )}
      </ScrollView>

      {/* Input bar */}
      {status === "connected" && (
        <View
          style={{
            paddingHorizontal: 12,
            paddingTop: 10,
            paddingBottom: insets.bottom + 10,
            backgroundColor: "#001020",
            borderTopWidth: 1,
            borderTopColor: "#002040",
            flexDirection: "row",
            gap: 8,
          }}
        >
          <TextInput
            placeholder="Enter command..."
            placeholderTextColor="#2A4A6A"
            value={input}
            onChangeText={setInput}
            onSubmitEditing={sendCommand}
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="send"
            style={{
              flex: 1,
              backgroundColor: "#000810",
              borderRadius: 10,
              borderWidth: 1,
              borderColor: "#002040",
              color: "#00FF88",
              fontFamily: "monospace",
              fontSize: 13,
              paddingHorizontal: 12,
              paddingVertical: 10,
            }}
          />
          <TouchableOpacity
            onPress={sendCommand}
            disabled={!input.trim()}
            style={{
              backgroundColor: input.trim() ? CYAN : "#002040",
              borderRadius: 10,
              paddingHorizontal: 16,
              paddingVertical: 10,
              justifyContent: "center",
            }}
          >
            <Text
              style={{
                color: input.trim() ? "#000F1A" : "#2A4A6A",
                fontWeight: "800",
                fontSize: 13,
              }}
            >
              Send
            </Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Floating rebuild button */}
      {status === "connected" && (
        <TouchableOpacity
          onPress={() => setShowRebuildModal(true)}
          style={{
            position: "absolute",
            right: 16,
            bottom: insets.bottom + 80,
            width: 54,
            height: 54,
            borderRadius: 27,
            backgroundColor: "#CC00CC",
            alignItems: "center",
            justifyContent: "center",
            shadowColor: "#FF00FF",
            shadowOffset: { width: 0, height: 4 },
            shadowOpacity: 0.5,
            shadowRadius: 10,
            elevation: 8,
          }}
        >
          <Text style={{ fontSize: 22 }}>🚀</Text>
        </TouchableOpacity>
      )}

      {/* ── Sessions Modal ── */}
      <Modal
        visible={showSessionsModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowSessionsModal(false)}
      >
        <View style={{ flex: 1, backgroundColor: BG }}>
          <View
            style={{
              paddingTop: insets.top + 12,
              paddingHorizontal: 18,
              paddingBottom: 12,
              backgroundColor: CARD,
              borderBottomWidth: 1,
              borderBottomColor: BORDER,
            }}
          >
            <View
              style={{
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <Text style={{ color: TEXT, fontSize: 18, fontWeight: "800" }}>
                ⊞ Sessions ({activeCount})
              </Text>
              <TouchableOpacity onPress={() => setShowSessionsModal(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>
          <ScrollView
            contentContainerStyle={{
              padding: 16,
              paddingBottom: insets.bottom + 20,
            }}
          >
            <View
              style={{
                backgroundColor: CYAN + "15",
                borderRadius: 10,
                borderWidth: 1,
                borderColor: CYAN + "40",
                padding: 12,
                marginBottom: 16,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 16 }}>💡</Text>
              <Text
                style={{ color: CYAN, fontSize: 12, flex: 1, lineHeight: 18 }}
              >
                Each session keeps its own live SSH connection. Switch freely —
                sessions run in the background. Open new ones from the VPS
                screen.
              </Text>
            </View>

            {allSessions.length === 0 && (
              <Text
                style={{
                  color: MUTED,
                  fontSize: 14,
                  textAlign: "center",
                  marginTop: 40,
                }}
              >
                No active sessions
              </Text>
            )}

            {allSessions.map((s) => {
              const cfg = getStatusConfig(s.status);
              const isActive = s.sessionId === sessionId;
              return (
                <TouchableOpacity
                  key={s.sessionId}
                  onPress={() => switchToSession(s.sessionId)}
                  style={{
                    backgroundColor: isActive ? CYAN + "20" : CARD,
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: isActive ? CYAN : BORDER,
                    padding: 14,
                    marginBottom: 10,
                    flexDirection: "row",
                    alignItems: "center",
                    gap: 12,
                  }}
                >
                  <Text style={{ fontSize: 24 }}>🖥️</Text>
                  <View style={{ flex: 1 }}>
                    <Text
                      style={{ color: TEXT, fontWeight: "700", fontSize: 14 }}
                    >
                      {s.serverNickname}
                    </Text>
                    <Text
                      style={{
                        color: CYAN,
                        fontSize: 11,
                        fontFamily: "monospace",
                        marginTop: 2,
                      }}
                    >
                      {s.serverIp}
                    </Text>
                    <View
                      style={{
                        flexDirection: "row",
                        alignItems: "center",
                        gap: 4,
                        marginTop: 4,
                      }}
                    >
                      <Text style={{ fontSize: 9 }}>{cfg.emoji}</Text>
                      <Text
                        style={{
                          color: cfg.color,
                          fontSize: 10,
                          fontWeight: "700",
                        }}
                      >
                        {cfg.label}
                      </Text>
                      {s.output.length > 0 && (
                        <Text style={{ color: MUTED, fontSize: 10 }}>
                          · {s.output.length} lines
                        </Text>
                      )}
                    </View>
                  </View>
                  {isActive && (
                    <View
                      style={{
                        backgroundColor: CYAN + "25",
                        borderRadius: 6,
                        paddingHorizontal: 8,
                        paddingVertical: 3,
                        marginRight: 6,
                      }}
                    >
                      <Text
                        style={{ color: CYAN, fontSize: 10, fontWeight: "700" }}
                      >
                        ACTIVE
                      </Text>
                    </View>
                  )}
                  <TouchableOpacity
                    onPress={() => closeSession(s.sessionId)}
                    style={{
                      backgroundColor: RED + "20",
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 6,
                    }}
                  >
                    <Text
                      style={{ color: RED, fontSize: 11, fontWeight: "700" }}
                    >
                      ✕
                    </Text>
                  </TouchableOpacity>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>
      </Modal>

      {/* ── Rebuild Modal ── */}
      <Modal
        visible={showRebuildModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowRebuildModal(false)}
      >
        <View style={{ flex: 1, backgroundColor: BG }}>
          <View
            style={{
              paddingTop: insets.top + 12,
              paddingHorizontal: 18,
              paddingBottom: 12,
              backgroundColor: CARD,
              borderBottomWidth: 1,
              borderBottomColor: BORDER,
            }}
          >
            <View
              style={{
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <Text style={{ color: TEXT, fontSize: 18, fontWeight: "800" }}>
                🚀 One-Click OS Rebuild
              </Text>
              <TouchableOpacity onPress={() => setShowRebuildModal(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>
          <ScrollView
            contentContainerStyle={{
              padding: 18,
              paddingBottom: insets.bottom + 20,
            }}
          >
            <View
              style={{
                backgroundColor: RED + "15",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: RED + "40",
                padding: 14,
                marginBottom: 20,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 22 }}>⚠️</Text>
              <Text
                style={{ color: RED, fontSize: 13, flex: 1, lineHeight: 18 }}
              >
                This will completely WIPE the current OS. VPS may be offline
                5–15 minutes. Backup first!
              </Text>
            </View>

            <View style={{ flexDirection: "row", gap: 10, marginBottom: 20 }}>
              {["linux", "windows"].map((cat) => (
                <TouchableOpacity
                  key={cat}
                  onPress={() => {
                    setSelectedCategory(cat);
                    setSelectedOS(null);
                    setSelectedVersion(null);
                  }}
                  style={{
                    flex: 1,
                    backgroundColor: selectedCategory === cat ? CYAN : CARD,
                    borderRadius: 10,
                    borderWidth: 1,
                    borderColor: selectedCategory === cat ? CYAN : BORDER,
                    paddingVertical: 12,
                    alignItems: "center",
                  }}
                >
                  <Text
                    style={{
                      color: selectedCategory === cat ? "#000F1A" : TEXT,
                      fontSize: 14,
                      fontWeight: "700",
                    }}
                  >
                    {cat === "linux" ? "🐧 Linux" : "🪟 Windows"}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 12,
              }}
            >
              Select OS
            </Text>
            {osData
              .filter((os) => os.category === selectedCategory)
              .map((os) => (
                <TouchableOpacity
                  key={os.id}
                  onPress={() => {
                    setSelectedOS(os);
                    setSelectedVersion(null);
                  }}
                  style={{
                    backgroundColor:
                      selectedOS?.id === os.id ? os.color + "25" : CARD,
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: selectedOS?.id === os.id ? os.color : BORDER,
                    padding: 14,
                    marginBottom: 10,
                    flexDirection: "row",
                    alignItems: "center",
                    gap: 12,
                  }}
                >
                  <Text style={{ fontSize: 26 }}>{os.icon}</Text>
                  <View style={{ flex: 1 }}>
                    <Text
                      style={{
                        color: TEXT,
                        fontSize: 15,
                        fontWeight: "700",
                        marginBottom: 2,
                      }}
                    >
                      {os.name}
                    </Text>
                    <Text style={{ color: MUTED, fontSize: 11 }}>
                      {os.description}
                    </Text>
                  </View>
                </TouchableOpacity>
              ))}

            {selectedOS && (
              <>
                <Text
                  style={{
                    color: TEXT,
                    fontSize: 13,
                    fontWeight: "700",
                    marginTop: 16,
                    marginBottom: 12,
                  }}
                >
                  Select Version
                </Text>
                <View
                  style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}
                >
                  {selectedOS.versions.map((v) => (
                    <TouchableOpacity
                      key={v.version}
                      onPress={() => setSelectedVersion(v)}
                      style={{
                        backgroundColor:
                          selectedVersion?.version === v.version ? TEAL : CARD,
                        borderRadius: 8,
                        borderWidth: 1,
                        borderColor:
                          selectedVersion?.version === v.version
                            ? TEAL
                            : BORDER,
                        paddingHorizontal: 14,
                        paddingVertical: 10,
                      }}
                    >
                      <Text
                        style={{
                          color:
                            selectedVersion?.version === v.version
                              ? "#000F1A"
                              : TEXT,
                          fontSize: 12,
                          fontWeight: "700",
                        }}
                      >
                        {v.version}
                        {v.codename ? ` (${v.codename})` : ""}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}

            <TouchableOpacity
              onPress={executeRebuild}
              disabled={!selectedOS || !selectedVersion}
              style={{
                backgroundColor:
                  selectedOS && selectedVersion ? "#CC00CC" : MUTED,
                borderRadius: 12,
                paddingVertical: 16,
                alignItems: "center",
                marginTop: 28,
              }}
            >
              <Text style={{ color: "#FFF", fontWeight: "800", fontSize: 15 }}>
                🚀 Execute Rebuild
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}
