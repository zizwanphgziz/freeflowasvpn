import { useState, useEffect, useCallback } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  Modal,
  Alert,
  ActivityIndicator,
  TextInput,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import * as Clipboard from "expo-clipboard";
import { useTheme } from "@/utils/ThemeContext";

const BACKEND_URL_KEY = "@freeflow_backend_url";
const STORAGE_KEY = "@freeflow_vps_list";

// File/folder icons
const getFileIcon = (name, isDir) => {
  if (isDir) return "📁";
  const ext = name.split(".").pop().toLowerCase();
  const icons = {
    sh: "📜",
    bash: "📜",
    py: "🐍",
    js: "📄",
    ts: "📄",
    json: "📋",
    yaml: "⚙️",
    yml: "⚙️",
    conf: "⚙️",
    config: "⚙️",
    log: "🗒️",
    txt: "📝",
    md: "📝",
    tar: "📦",
    gz: "📦",
    zip: "📦",
    bz2: "📦",
    db: "🗄️",
    sql: "🗄️",
    key: "🔑",
    pem: "🔑",
    crt: "🔒",
    cert: "🔒",
    service: "⚡",
    socket: "⚡",
  };
  return icons[ext] || "📄";
};

const formatSize = (bytes) => {
  if (bytes === undefined || bytes === null) return "";
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
};

const formatPerms = (mode) => {
  if (!mode) return "";
  return mode.toString(8).slice(-3);
};

export default function FileManagerScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const params = useLocalSearchParams();
  const { theme } = useTheme();
  const { BG, CARD, BORDER, CYAN, TEAL, TEXT, MUTED, GREEN, RED, ORANGE } =
    theme;

  const [server, setServer] = useState(null);
  const [ws, setWs] = useState(null);
  const [status, setStatus] = useState("disconnected");
  const [currentPath, setCurrentPath] = useState("/root");
  const [pathHistory, setPathHistory] = useState([]);
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedItem, setSelectedItem] = useState(null);
  const [showActionsModal, setShowActionsModal] = useState(false);
  const [showNewFolderModal, setShowNewFolderModal] = useState(false);
  const [showSetupGuide, setShowSetupGuide] = useState(false);
  const [backendUrl, setBackendUrl] = useState("");
  const [newFolderName, setNewFolderName] = useState("");
  const [viewingFile, setViewingFile] = useState(null); // { name, content }

  useEffect(() => {
    bootstrap();
    return () => {
      if (ws)
        try {
          ws.close();
        } catch (_) {}
    };
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
      const srv = servers.find((s) => s.id === params.serverId);
      if (!srv) {
        Alert.alert("Error", "Server not found");
        router.back();
        return;
      }
      setServer(srv);
      connectSFTP(srv, url);
    } catch (e) {
      console.error("filemanager bootstrap error", e);
    }
  };

  const connectSFTP = (srv, wsUrl) => {
    setStatus("connecting");

    let endpoint = wsUrl.replace(/^http/, "ws");
    if (!endpoint.endsWith("/")) endpoint += "/";
    endpoint += "ws/sftp";

    const websocket = new WebSocket(endpoint);

    websocket.onopen = () => {
      setStatus("authenticating");
      websocket.send(
        JSON.stringify({
          host: srv.ip,
          port: 22,
          username: "root",
          password: srv.passwordHint || "",
        }),
      );
    };

    websocket.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === "connected") {
          setStatus("connected");
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          listDirectory("/root", websocket);
        } else if (msg.type === "list") {
          setItems(msg.data || []);
          setLoading(false);
        } else if (msg.type === "file_content") {
          setViewingFile({ name: msg.name, content: msg.data });
          setLoading(false);
        } else if (msg.type === "success") {
          listDirectory(currentPath, websocket);
        } else if (msg.type === "error") {
          Alert.alert("Error", msg.data);
          setLoading(false);
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        }
      } catch (_) {}
    };

    websocket.onerror = () => {
      setStatus("error");
      Alert.alert(
        "Connection Error",
        "Could not connect to SFTP backend. Check the backend URL in VPS settings.",
      );
    };

    websocket.onclose = () => {
      setStatus("disconnected");
    };

    setWs(websocket);
  };

  const listDirectory = useCallback(
    (path, wsRef = ws) => {
      if (!wsRef) return;
      setLoading(true);
      setCurrentPath(path);
      wsRef.send(JSON.stringify({ type: "list", path }));
    },
    [ws],
  );

  const navigateInto = (item) => {
    if (!item.isDirectory) {
      readFile(item.path);
      return;
    }
    setPathHistory((h) => [...h, currentPath]);
    listDirectory(item.path);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const navigateBack = () => {
    if (pathHistory.length === 0) return;
    const prev = pathHistory[pathHistory.length - 1];
    setPathHistory((h) => h.slice(0, -1));
    listDirectory(prev);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const readFile = (path) => {
    if (!ws) return;
    setLoading(true);
    ws.send(JSON.stringify({ type: "read", path }));
  };

  const deleteItem = (item) => {
    Alert.alert(
      `Delete ${item.isDirectory ? "Folder" : "File"}`,
      `Delete "${item.name}"?${item.isDirectory ? "\n\nThis will delete the folder and ALL its contents!" : ""}`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: () => {
            if (!ws) return;
            setShowActionsModal(false);
            ws.send(
              JSON.stringify({
                type: "delete",
                path: item.path,
                isDirectory: item.isDirectory,
              }),
            );
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          },
        },
      ],
    );
  };

  const createFolder = () => {
    if (!newFolderName.trim() || !ws) return;
    const path = `${currentPath}/${newFolderName.trim()}`;
    ws.send(JSON.stringify({ type: "mkdir", path }));
    setShowNewFolderModal(false);
    setNewFolderName("");
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const copyPath = async (item) => {
    await Clipboard.setStringAsync(item.path);
    setShowActionsModal(false);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    Alert.alert("Copied", `Path copied:\n${item.path}`);
  };

  const getStatusConfig = () => {
    switch (status) {
      case "connected":
        return { emoji: "🟢", color: GREEN, label: "Connected" };
      case "connecting":
      case "authenticating":
        return {
          emoji: "🟡",
          color: ORANGE,
          label:
            status === "connecting" ? "Connecting..." : "Authenticating...",
        };
      case "error":
        return { emoji: "🔴", color: RED, label: "Error" };
      default:
        return { emoji: "⚫", color: MUTED, label: "Disconnected" };
    }
  };

  const statusCfg = getStatusConfig();

  // ── Breadcrumb path segments ──
  const pathParts = currentPath.split("/").filter(Boolean);

  // ── Setup guide ──
  if (showSetupGuide) {
    return (
      <View style={{ flex: 1, backgroundColor: BG }}>
        <StatusBar style="dark" />
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
        <View
          style={{
            flex: 1,
            alignItems: "center",
            justifyContent: "center",
            padding: 24,
          }}
        >
          <Text style={{ fontSize: 48, marginBottom: 16 }}>📁</Text>
          <Text
            style={{
              color: TEXT,
              fontSize: 20,
              fontWeight: "800",
              textAlign: "center",
              marginBottom: 12,
            }}
          >
            Backend Required
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
            Configure your backend URL in VPS Settings (⚙️ Backend) to use the
            File Manager.
          </Text>
          <TouchableOpacity
            onPress={() => router.back()}
            style={{
              backgroundColor: CYAN,
              borderRadius: 12,
              paddingHorizontal: 28,
              paddingVertical: 14,
            }}
          >
            <Text style={{ color: "#000F1A", fontWeight: "800", fontSize: 14 }}>
              ← Go Back
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: BG }}>
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
        }}
      >
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            gap: 10,
            marginBottom: 8,
          }}
        >
          <TouchableOpacity onPress={() => router.back()}>
            <Text style={{ color: CYAN, fontSize: 15, fontWeight: "700" }}>
              ←
            </Text>
          </TouchableOpacity>
          <View style={{ flex: 1 }}>
            <Text style={{ color: "#FFF", fontSize: 14, fontWeight: "800" }}>
              📁 File Manager
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
                  color: "#3A6080",
                  fontSize: 10,
                  fontFamily: "monospace",
                }}
              >
                {server?.nickname}
              </Text>
            </View>
          </View>
          {status === "connected" && (
            <TouchableOpacity
              onPress={() => setShowNewFolderModal(true)}
              style={{
                backgroundColor: TEAL + "25",
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 6,
                borderWidth: 1,
                borderColor: TEAL,
              }}
            >
              <Text style={{ color: TEAL, fontSize: 11, fontWeight: "700" }}>
                + Folder
              </Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Breadcrumb */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
            <TouchableOpacity
              onPress={() => {
                setPathHistory([]);
                listDirectory("/root");
              }}
            >
              <Text
                style={{
                  color: CYAN,
                  fontSize: 11,
                  fontFamily: "monospace",
                  fontWeight: "700",
                }}
              >
                ~
              </Text>
            </TouchableOpacity>
            {pathParts.map((part, idx) => (
              <View
                key={idx}
                style={{ flexDirection: "row", alignItems: "center", gap: 4 }}
              >
                <Text style={{ color: "#2A4060", fontSize: 11 }}>/</Text>
                <TouchableOpacity
                  onPress={() => {
                    const target = "/" + pathParts.slice(0, idx + 1).join("/");
                    const newHistory = pathHistory.slice(
                      0,
                      pathHistory.length - (pathParts.length - idx - 1),
                    );
                    setPathHistory(newHistory);
                    listDirectory(target);
                  }}
                >
                  <Text
                    style={{
                      color: idx === pathParts.length - 1 ? "#FFF" : CYAN,
                      fontSize: 11,
                      fontFamily: "monospace",
                    }}
                  >
                    {part}
                  </Text>
                </TouchableOpacity>
              </View>
            ))}
          </View>
        </ScrollView>
      </View>

      {/* Back row */}
      {pathHistory.length > 0 && (
        <TouchableOpacity
          onPress={navigateBack}
          style={{
            flexDirection: "row",
            alignItems: "center",
            gap: 10,
            paddingHorizontal: 16,
            paddingVertical: 12,
            backgroundColor: CARD,
            borderBottomWidth: 1,
            borderBottomColor: BORDER,
          }}
        >
          <Text style={{ fontSize: 20 }}>↩️</Text>
          <Text style={{ color: CYAN, fontSize: 14, fontWeight: "700" }}>
            .. (Go Up)
          </Text>
        </TouchableOpacity>
      )}

      {/* Loading */}
      {(loading || status === "connecting" || status === "authenticating") && (
        <View style={{ padding: 24, alignItems: "center" }}>
          <ActivityIndicator color={CYAN} size="large" />
          <Text style={{ color: MUTED, fontSize: 13, marginTop: 10 }}>
            {status === "connecting"
              ? "Connecting..."
              : status === "authenticating"
                ? "Authenticating..."
                : "Loading..."}
          </Text>
        </View>
      )}

      {/* File list */}
      {status === "connected" && !loading && (
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingBottom: insets.bottom + 20 }}
          showsVerticalScrollIndicator={false}
        >
          {items.length === 0 && (
            <View style={{ alignItems: "center", paddingTop: 60 }}>
              <Text style={{ fontSize: 40, marginBottom: 12 }}>📭</Text>
              <Text style={{ color: MUTED, fontSize: 14 }}>
                Empty directory
              </Text>
            </View>
          )}

          {/* Directories first, then files */}
          {[...items]
            .sort((a, b) => {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              return a.name.localeCompare(b.name);
            })
            .map((item, idx) => (
              <TouchableOpacity
                key={idx}
                onPress={() => navigateInto(item)}
                onLongPress={() => {
                  setSelectedItem(item);
                  setShowActionsModal(true);
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
                }}
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 12,
                  paddingHorizontal: 16,
                  paddingVertical: 12,
                  borderBottomWidth: 1,
                  borderBottomColor: BORDER,
                }}
              >
                <Text style={{ fontSize: 22, width: 28, textAlign: "center" }}>
                  {getFileIcon(item.name, item.isDirectory)}
                </Text>
                <View style={{ flex: 1 }}>
                  <Text
                    style={{
                      color: TEXT,
                      fontSize: 14,
                      fontWeight: item.isDirectory ? "700" : "400",
                    }}
                    numberOfLines={1}
                  >
                    {item.name}
                  </Text>
                  <View style={{ flexDirection: "row", gap: 10, marginTop: 2 }}>
                    {!item.isDirectory && item.size !== undefined && (
                      <Text style={{ color: MUTED, fontSize: 11 }}>
                        {formatSize(item.size)}
                      </Text>
                    )}
                    {item.mode !== undefined && (
                      <Text
                        style={{
                          color: MUTED,
                          fontSize: 11,
                          fontFamily: "monospace",
                        }}
                      >
                        {formatPerms(item.mode)}
                      </Text>
                    )}
                    {item.modifyTime && (
                      <Text style={{ color: MUTED, fontSize: 11 }}>
                        {new Date(item.modifyTime * 1000).toLocaleDateString()}
                      </Text>
                    )}
                  </View>
                </View>
                {item.isDirectory && (
                  <Text style={{ color: MUTED, fontSize: 16 }}>›</Text>
                )}
              </TouchableOpacity>
            ))}
        </ScrollView>
      )}

      {/* Status info when disconnected */}
      {status === "disconnected" && (
        <View
          style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
        >
          <Text style={{ fontSize: 40, marginBottom: 12 }}>📡</Text>
          <Text style={{ color: MUTED, fontSize: 14 }}>Not connected</Text>
        </View>
      )}

      {/* ── File Actions Modal (long press) ── */}
      <Modal
        visible={showActionsModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowActionsModal(false)}
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
              <View
                style={{ flexDirection: "row", alignItems: "center", gap: 10 }}
              >
                <Text style={{ fontSize: 24 }}>
                  {selectedItem
                    ? getFileIcon(selectedItem.name, selectedItem.isDirectory)
                    : "📄"}
                </Text>
                <Text
                  style={{ color: TEXT, fontSize: 16, fontWeight: "800" }}
                  numberOfLines={1}
                >
                  {selectedItem?.name}
                </Text>
              </View>
              <TouchableOpacity onPress={() => setShowActionsModal(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
            <Text
              style={{
                color: MUTED,
                fontSize: 11,
                fontFamily: "monospace",
                marginTop: 4,
              }}
            >
              {selectedItem?.path}
            </Text>
          </View>

          <View style={{ padding: 16, gap: 10 }}>
            {selectedItem && !selectedItem.isDirectory && (
              <TouchableOpacity
                onPress={() => {
                  setShowActionsModal(false);
                  readFile(selectedItem.path);
                }}
                style={{
                  backgroundColor: CARD,
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: BORDER,
                  padding: 16,
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 14,
                }}
              >
                <Text style={{ fontSize: 22 }}>👁️</Text>
                <View>
                  <Text
                    style={{ color: TEXT, fontWeight: "700", fontSize: 14 }}
                  >
                    View File
                  </Text>
                  <Text style={{ color: MUTED, fontSize: 11, marginTop: 2 }}>
                    Read file contents
                  </Text>
                </View>
              </TouchableOpacity>
            )}

            <TouchableOpacity
              onPress={() => copyPath(selectedItem)}
              style={{
                backgroundColor: CARD,
                borderRadius: 12,
                borderWidth: 1,
                borderColor: BORDER,
                padding: 16,
                flexDirection: "row",
                alignItems: "center",
                gap: 14,
              }}
            >
              <Text style={{ fontSize: 22 }}>📋</Text>
              <View>
                <Text style={{ color: TEXT, fontWeight: "700", fontSize: 14 }}>
                  Copy Path
                </Text>
                <Text style={{ color: MUTED, fontSize: 11, marginTop: 2 }}>
                  Copy full file path to clipboard
                </Text>
              </View>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => {
                setShowActionsModal(false);
                deleteItem(selectedItem);
              }}
              style={{
                backgroundColor: RED + "15",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: RED + "40",
                padding: 16,
                flexDirection: "row",
                alignItems: "center",
                gap: 14,
              }}
            >
              <Text style={{ fontSize: 22 }}>🗑️</Text>
              <View>
                <Text style={{ color: RED, fontWeight: "700", fontSize: 14 }}>
                  Delete
                </Text>
                <Text style={{ color: RED + "AA", fontSize: 11, marginTop: 2 }}>
                  {selectedItem?.isDirectory
                    ? "Delete folder and all contents"
                    : "Permanently delete file"}
                </Text>
              </View>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* ── New Folder Modal ── */}
      <Modal
        visible={showNewFolderModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setShowNewFolderModal(false)}
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
                📁 New Folder
              </Text>
              <TouchableOpacity onPress={() => setShowNewFolderModal(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>
          <View style={{ padding: 18 }}>
            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Folder Name
            </Text>
            <TextInput
              placeholder="e.g. my-configs"
              placeholderTextColor={MUTED}
              value={newFolderName}
              onChangeText={setNewFolderName}
              autoFocus
              autoCapitalize="none"
              autoCorrect={false}
              style={{
                backgroundColor: CARD,
                borderRadius: 10,
                borderWidth: 1,
                borderColor: BORDER,
                color: TEXT,
                fontSize: 14,
                paddingHorizontal: 14,
                paddingVertical: 12,
                marginBottom: 8,
              }}
            />
            <Text style={{ color: MUTED, fontSize: 11, marginBottom: 24 }}>
              Will be created at: {currentPath}/
            </Text>
            <TouchableOpacity
              onPress={createFolder}
              disabled={!newFolderName.trim()}
              style={{
                backgroundColor: newFolderName.trim() ? TEAL : MUTED,
                borderRadius: 12,
                paddingVertical: 16,
                alignItems: "center",
              }}
            >
              <Text
                style={{ color: "#000F1A", fontWeight: "800", fontSize: 15 }}
              >
                Create Folder
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* ── File Viewer Modal ── */}
      <Modal
        visible={!!viewingFile}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setViewingFile(null)}
      >
        <View style={{ flex: 1, backgroundColor: "#000F1A" }}>
          <View
            style={{
              paddingTop: insets.top + 12,
              paddingHorizontal: 18,
              paddingBottom: 12,
              backgroundColor: "#001020",
              borderBottomWidth: 1,
              borderBottomColor: "#002040",
            }}
          >
            <View
              style={{
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <Text
                style={{ color: "#FFF", fontSize: 15, fontWeight: "800" }}
                numberOfLines={1}
              >
                👁️ {viewingFile?.name}
              </Text>
              <View style={{ flexDirection: "row", gap: 10 }}>
                <TouchableOpacity
                  onPress={async () => {
                    if (viewingFile?.content) {
                      await Clipboard.setStringAsync(viewingFile.content);
                      Haptics.notificationAsync(
                        Haptics.NotificationFeedbackType.Success,
                      );
                    }
                  }}
                  style={{
                    backgroundColor: CYAN + "25",
                    borderRadius: 8,
                    paddingHorizontal: 10,
                    paddingVertical: 6,
                  }}
                >
                  <Text
                    style={{ color: CYAN, fontSize: 11, fontWeight: "700" }}
                  >
                    📋 Copy
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => setViewingFile(null)}>
                  <Text style={{ color: "#888", fontSize: 28 }}>×</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
          <ScrollView
            contentContainerStyle={{
              padding: 12,
              paddingBottom: insets.bottom + 20,
            }}
          >
            <Text
              style={{
                color: "#00FF88",
                fontFamily: "monospace",
                fontSize: 12,
                lineHeight: 18,
              }}
            >
              {viewingFile?.content || "(empty file)"}
            </Text>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}
