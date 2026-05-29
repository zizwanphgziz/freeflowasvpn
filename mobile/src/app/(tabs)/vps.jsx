import { useState, useCallback, useEffect } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Modal,
  Alert,
  Share,
} from "react-native";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useTheme } from "@/utils/ThemeContext";
import { useRouter } from "expo-router";

const LOGO =
  "https://dtvoeevhaseb5.cloudfront.net/user-uploads/f8f5b2b0-a11f-4713-8f86-06409841e8a9.jpg";
const STORAGE_KEY = "@freeflow_vps_list";
const BACKEND_URL_KEY = "@freeflow_backend_url";

const PROVIDERS = [
  "Vultr",
  "Hetzner",
  "DigitalOcean",
  "Linode",
  "Contabo",
  "OVH",
  "Netcup",
  "Scaleway",
  "AWS Lightsail",
  "Google Cloud",
  "Azure",
  "Other",
];

const OS_OPTIONS = [
  "Debian 13",
  "Debian 12",
  "Debian 11",
  "Debian 10",
  "Debian 9",
  "Ubuntu 24.04 LTS",
  "Ubuntu 22.04 LTS",
  "Ubuntu 20.04 LTS",
  "Ubuntu 18.04 LTS",
  "CentOS 9 Stream",
  "CentOS 8",
  "CentOS 7",
  "AlmaLinux 9",
  "AlmaLinux 8",
  "Rocky Linux 9",
  "Rocky Linux 8",
  "Fedora 40",
  "openSUSE Leap",
  "Arch Linux",
  "Other",
];

// One-liner that mirrors BACKEND_SETUP.md on the zizwanphgziz/freeflowonelinerrebuildvps repo.
// Installs deps, clones (or pulls latest) the repo, sets up the Python venv,
// copies the systemd service, opens port 8000 in UFW (if active), and starts
// the backend listening on 0.0.0.0:8000.
const BACKEND_SETUP_SCRIPT =
  "apt update && apt install -y git python3-venv lsof curl && " +
  "(test -d /root/freeflowonelinerrebuildvps && cd /root/freeflowonelinerrebuildvps && git pull --ff-only " +
  "|| git clone https://github.com/zizwanphgziz/freeflowonelinerrebuildvps.git /root/freeflowonelinerrebuildvps) && " +
  "cd /root/freeflowonelinerrebuildvps/backend && " +
  "python3 -m venv venv && " +
  "./venv/bin/pip install --upgrade fastapi asyncssh uvicorn websockets && " +
  "cp freeflow.service /etc/systemd/system/ && " +
  "systemctl daemon-reload && " +
  "systemctl enable --now freeflow && " +
  "systemctl restart freeflow && " +
  "(command -v ufw >/dev/null 2>&1 && ufw status | grep -q active && ufw allow 8000/tcp || true) && " +
  "sleep 2 && " +
  "curl -fsS http://127.0.0.1:8000/healthz && echo && " +
  "echo '✓ Freeflow backend ready on port 8000 — paste ws://<this VPS IP>:8000 into the app'";

export default function VpsScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { theme } = useTheme();
  const {
    BG,
    CARD,
    BORDER,
    CYAN,
    TEAL,
    TEXT,
    MUTED,
    GREEN,
    RED,
    ORANGE,
    STATUS_BAR,
  } = theme;

  const STATUS_OPTIONS = [
    { label: "Active", color: GREEN },
    { label: "Rebuilding", color: ORANGE },
    { label: "Offline", color: RED },
  ];

  const [servers, setServers] = useState([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [importModalVisible, setImportModalVisible] = useState(false);
  const [backendSettingsVisible, setBackendSettingsVisible] = useState(false);
  const [backendUrl, setBackendUrl] = useState("");
  const [importText, setImportText] = useState("");
  const [editingId, setEditingId] = useState(null);
  const [copiedSSH, setCopiedSSH] = useState(null);
  const [copiedSetup, setCopiedSetup] = useState(false);
  const [expandedId, setExpandedId] = useState(null);
  const [testingBackend, setTestingBackend] = useState(false);

  // Form state
  const [nickname, setNickname] = useState("");
  const [ip, setIp] = useState("");
  const [sshUsername, setSshUsername] = useState("root");
  const [sshPort, setSshPort] = useState("22");
  const [provider, setProvider] = useState("Vultr");
  const [currentOS, setCurrentOS] = useState("");
  const [showOSPicker, setShowOSPicker] = useState(false);
  const [osIsCustom, setOsIsCustom] = useState(false);
  const [passwordHint, setPasswordHint] = useState("");
  const [notes, setNotes] = useState("");
  const [status, setStatus] = useState("Active");

  useEffect(() => {
    loadServers();
    loadBackendUrl();
  }, []);

  const loadServers = async () => {
    try {
      const data = await AsyncStorage.getItem(STORAGE_KEY);
      if (data) setServers(JSON.parse(data));
    } catch (e) {
      console.error("Failed to load servers", e);
    }
  };

  const loadBackendUrl = async () => {
    try {
      const url = await AsyncStorage.getItem(BACKEND_URL_KEY);
      if (url) setBackendUrl(url);
    } catch (e) {
      console.error("Failed to load backend URL", e);
    }
  };

  const saveBackendUrl = async () => {
    try {
      await AsyncStorage.setItem(BACKEND_URL_KEY, backendUrl.trim());
      setBackendSettingsVisible(false);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert("Saved", "Backend URL saved successfully");
    } catch (e) {
      console.error("Failed to save backend URL", e);
      Alert.alert("Error", "Failed to save backend URL");
    }
  };

  const saveServers = async (newServers) => {
    try {
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(newServers));
      setServers(newServers);
    } catch (e) {
      console.error("Failed to save servers", e);
    }
  };

  const resetForm = () => {
    setNickname("");
    setIp("");
    setSshUsername("root");
    setSshPort("22");
    setProvider("Vultr");
    setCurrentOS("");
    setOsIsCustom(false);
    setShowOSPicker(false);
    setPasswordHint("");
    setNotes("");
    setStatus("Active");
  };

  const openAddModal = () => {
    resetForm();
    setEditingId(null);
    setModalVisible(true);
  };

  const openEditModal = (server) => {
    setEditingId(server.id);
    setNickname(server.nickname);
    setIp(server.ip);
    setSshUsername(server.sshUsername || "root");
    setSshPort(server.sshPort ? String(server.sshPort) : "22");
    setProvider(server.provider);
    setCurrentOS(server.currentOS || "");
    setOsIsCustom(!!(server.currentOS && !OS_OPTIONS.includes(server.currentOS)));
    setShowOSPicker(false);
    setPasswordHint(server.passwordHint);
    setNotes(server.notes);
    setStatus(server.status);
    setModalVisible(true);
  };

  const handleSave = () => {
    if (!nickname.trim() || !ip.trim()) {
      Alert.alert("Required", "Nickname and IP are required");
      return;
    }
    const portNum = parseInt(sshPort.trim() || "22", 10);
    const newServer = {
      id: editingId || Date.now().toString(),
      nickname: nickname.trim(),
      ip: ip.trim(),
      sshUsername: (sshUsername.trim() || "root"),
      sshPort: Number.isFinite(portNum) && portNum > 0 ? portNum : 22,
      provider,
      currentOS: currentOS.trim(),
      passwordHint: passwordHint.trim(),
      notes: notes.trim(),
      status,
      createdAt: editingId
        ? servers.find((s) => s.id === editingId)?.createdAt
        : Date.now(),
      updatedAt: Date.now(),
    };
    const updated = editingId
      ? servers.map((s) => (s.id === editingId ? newServer : s))
      : [...servers, newServer];
    saveServers(updated);
    setModalVisible(false);
    resetForm();
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  const handleDelete = (id) => {
    Alert.alert("Delete VPS", "Are you sure? This cannot be undone.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: () => {
          saveServers(servers.filter((s) => s.id !== id));
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        },
      },
    ]);
  };

  const handleCopySSH = async (server) => {
    const u = server.sshUsername || "root";
    const p = server.sshPort || 22;
    const cmd = p === 22 ? `ssh ${u}@${server.ip}` : `ssh ${u}@${server.ip} -p ${p}`;
    await Clipboard.setStringAsync(cmd);
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedSSH(server.id);
    setTimeout(() => setCopiedSSH(null), 2000);
  };

  const handleCopySetupScript = async () => {
    await Clipboard.setStringAsync(BACKEND_SETUP_SCRIPT);
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedSetup(true);
    setTimeout(() => setCopiedSetup(false), 2000);
  };

  const handleTestBackend = async () => {
    const raw = backendUrl.trim();
    if (!raw) {
      Alert.alert("Backend URL required", "Paste your backend URL first.");
      return;
    }
    // Convert ws://host:port → http://host:port for the healthz probe
    const httpUrl = raw.replace(/^ws/i, "http").replace(/\/+$/, "");
    const target = `${httpUrl}/healthz`;
    setTestingBackend(true);
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 8000);
      const res = await fetch(target, { signal: ctrl.signal });
      clearTimeout(timer);
      if (res.ok) {
        const body = await res.text();
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        Alert.alert(
          "Backend reachable ✓",
          `${target}\n\nResponse: ${body.slice(0, 120)}`,
        );
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        Alert.alert(
          "Backend responded with " + res.status,
          `${target}\n\nMake sure the freeflow systemd service is running and port 8000 is reachable from this device.`,
        );
      }
    } catch (e) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Alert.alert(
        "Backend NOT reachable",
        `Could not reach ${target}\n\nChecklist:\n• ssh into VPS and run: systemctl status freeflow\n• Confirm port 8000 is open: ss -tlnp | grep 8000\n• If UFW is active: ufw allow 8000/tcp\n• Cloud provider firewall: allow inbound TCP 8000\n• URL format: ws://<public-ip>:8000 (no trailing path)`,
      );
    } finally {
      setTestingBackend(false);
    }
  };

  // ── Export ──
  const handleExport = async () => {
    if (servers.length === 0) {
      Alert.alert("Nothing to export", "Add some VPS servers first.");
      return;
    }
    const exportData = {
      app: "FreeFlow VPS Toolkit",
      exportedAt: new Date().toISOString(),
      version: 1,
      servers,
    };
    try {
      await Share.share({
        message: JSON.stringify(exportData, null, 2),
        title: "FreeFlow VPS Export",
      });
    } catch (e) {
      console.error("Export failed", e);
      Alert.alert("Export failed", "Could not open share sheet.");
    }
  };

  // ── Import ──
  const handleImport = () => {
    if (!importText.trim()) {
      Alert.alert("Empty", "Paste your exported JSON first.");
      return;
    }
    try {
      const parsed = JSON.parse(importText.trim());
      const incoming = parsed.servers || parsed;
      if (!Array.isArray(incoming)) throw new Error("Invalid format");

      // Validate minimal structure
      const valid = incoming.filter((s) => s.id && s.nickname && s.ip);
      if (valid.length === 0) throw new Error("No valid servers found");

      Alert.alert(
        "Import VPS Data",
        `Found ${valid.length} server(s). How would you like to import?`,
        [
          { text: "Cancel", style: "cancel" },
          {
            text: "Merge",
            onPress: () => {
              const existingIds = new Set(servers.map((s) => s.id));
              const merged = [
                ...servers,
                ...valid.filter((s) => !existingIds.has(s.id)),
              ];
              saveServers(merged);
              setImportModalVisible(false);
              setImportText("");
              Haptics.notificationAsync(
                Haptics.NotificationFeedbackType.Success,
              );
            },
          },
          {
            text: "Replace All",
            style: "destructive",
            onPress: () => {
              saveServers(valid);
              setImportModalVisible(false);
              setImportText("");
              Haptics.notificationAsync(
                Haptics.NotificationFeedbackType.Success,
              );
            },
          },
        ],
      );
    } catch (e) {
      Alert.alert(
        "Invalid JSON",
        "The pasted data is not valid FreeFlow export JSON.",
      );
    }
  };

  const getStatusColor = (statusLabel) =>
    STATUS_OPTIONS.find((s) => s.label === statusLabel)?.color || CYAN;

  return (
    <View style={{ flex: 1, backgroundColor: BG }}>
      <StatusBar style={STATUS_BAR} />

      {/* Header */}
      <View
        style={{
          paddingTop: insets.top + 6,
          paddingHorizontal: 18,
          paddingBottom: 14,
          backgroundColor: BG,
        }}
      >
        <Image
          source={{ uri: LOGO }}
          style={{ width: 180, height: 52, marginBottom: 8 }}
          contentFit="contain"
        />
        <Text
          style={{
            color: MUTED,
            fontSize: 13,
            marginBottom: 10,
          }}
        >
          My VPS Servers
        </Text>
        <View style={{ flexDirection: "row", gap: 8 }}>
          <TouchableOpacity
            onPress={() => setBackendSettingsVisible(true)}
            style={{
              flex: 1,
              backgroundColor: CARD,
              borderRadius: 8,
              paddingVertical: 9,
              borderWidth: 1,
              borderColor: BORDER,
              alignItems: "center",
            }}
          >
            <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
              ⚙️ Backend
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={() => setImportModalVisible(true)}
            style={{
              flex: 1,
              backgroundColor: CARD,
              borderRadius: 8,
              paddingVertical: 9,
              borderWidth: 1,
              borderColor: BORDER,
              alignItems: "center",
            }}
          >
            <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
              📥 Import
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={handleExport}
            style={{
              flex: 1,
              backgroundColor: CARD,
              borderRadius: 8,
              paddingVertical: 9,
              borderWidth: 1,
              borderColor: BORDER,
              alignItems: "center",
            }}
          >
            <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
              📤 Export
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={openAddModal}
            style={{
              flex: 1.1,
              backgroundColor: CYAN,
              borderRadius: 8,
              paddingVertical: 9,
              alignItems: "center",
            }}
          >
            <Text
              style={{ color: "#000F1A", fontWeight: "800", fontSize: 12 }}
            >
              ➕ Add VPS
            </Text>
          </TouchableOpacity>
        </View>

        {/* Stats */}
        {servers.length > 0 && (
          <View style={{ flexDirection: "row", gap: 8, marginTop: 12 }}>
            {[
              { label: "Total", value: servers.length, color: CYAN },
              {
                label: "Active",
                value: servers.filter((s) => s.status === "Active").length,
                color: GREEN,
              },
              {
                label: "Rebuilding",
                value: servers.filter((s) => s.status === "Rebuilding").length,
                color: ORANGE,
              },
              {
                label: "Offline",
                value: servers.filter((s) => s.status === "Offline").length,
                color: RED,
              },
            ].map(({ label, value, color }) => (
              <View
                key={label}
                style={{
                  flex: 1,
                  backgroundColor: CARD,
                  borderRadius: 10,
                  borderWidth: 1,
                  borderColor: BORDER,
                  padding: 8,
                  alignItems: "center",
                }}
              >
                <Text style={{ color, fontWeight: "800", fontSize: 18 }}>
                  {value}
                </Text>
                <Text style={{ color: MUTED, fontSize: 10, marginTop: 2 }}>
                  {label}
                </Text>
              </View>
            ))}
          </View>
        )}
      </View>

      {/* Server list */}
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingBottom: insets.bottom + 90,
        }}
        showsVerticalScrollIndicator={false}
      >
        {servers.length === 0 && (
          <View style={{ alignItems: "center", paddingTop: 60 }}>
            <Text style={{ fontSize: 52, marginBottom: 12 }}>🌐</Text>
            <Text
              style={{
                color: TEXT,
                fontSize: 16,
                fontWeight: "700",
                marginBottom: 6,
              }}
            >
              No VPS servers yet
            </Text>
            <Text
              style={{
                color: MUTED,
                fontSize: 13,
                textAlign: "center",
                paddingHorizontal: 40,
              }}
            >
              Tap "Add VPS" to add a server (IP, SSH user/password, port…), or "Import" to restore a
              backup
            </Text>
          </View>
        )}

        {servers.map((server) => {
          const statusColor = getStatusColor(server.status);
          const isExpanded = expandedId === server.id;
          return (
            <View
              key={server.id}
              style={{
                backgroundColor: CARD,
                borderRadius: 14,
                borderWidth: 1,
                borderColor: isExpanded ? statusColor : BORDER,
                marginBottom: 10,
                overflow: "hidden",
              }}
            >
              {/* Card header – always visible */}
              <TouchableOpacity
                activeOpacity={0.8}
                onPress={() => setExpandedId(isExpanded ? null : server.id)}
                style={{
                  padding: 14,
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <View
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: 12,
                    backgroundColor: statusColor + "20",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Text style={{ fontSize: 22 }}>🖥️</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text
                    style={{ color: TEXT, fontWeight: "800", fontSize: 15 }}
                  >
                    {server.nickname}
                  </Text>
                  <Text
                    style={{
                      color: CYAN,
                      fontSize: 12,
                      fontFamily: "monospace",
                      marginTop: 2,
                    }}
                  >
                    {server.ip}
                  </Text>
                </View>
                <View style={{ alignItems: "flex-end", gap: 4 }}>
                  <View
                    style={{
                      backgroundColor: statusColor + "25",
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 3,
                    }}
                  >
                    <Text
                      style={{
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: "700",
                      }}
                    >
                      {server.status.toUpperCase()}
                    </Text>
                  </View>
                  <Text style={{ color: MUTED, fontSize: 11 }}>
                    {server.provider}
                  </Text>
                </View>
              </TouchableOpacity>

              {/* Expanded details */}
              {isExpanded && (
                <View
                  style={{
                    paddingHorizontal: 14,
                    paddingBottom: 14,
                    borderTopWidth: 1,
                    borderTopColor: BORDER,
                  }}
                >
                  <View style={{ gap: 8, marginTop: 12, marginBottom: 14 }}>
                    {server.currentOS ? (
                      <View style={{ flexDirection: "row", gap: 8 }}>
                        <Text style={{ color: MUTED, fontSize: 12, width: 90 }}>
                          Current OS:
                        </Text>
                        <Text style={{ color: TEXT, fontSize: 12 }}>
                          {server.currentOS}
                        </Text>
                      </View>
                    ) : null}
                    {server.passwordHint ? (
                      <View style={{ flexDirection: "row", gap: 8 }}>
                        <Text style={{ color: MUTED, fontSize: 12, width: 90 }}>
                          Pass hint:
                        </Text>
                        <Text style={{ color: TEXT, fontSize: 12 }}>
                          {"•".repeat(6)} ({server.passwordHint})
                        </Text>
                      </View>
                    ) : null}
                    {server.notes ? (
                      <View style={{ flexDirection: "row", gap: 8 }}>
                        <Text style={{ color: MUTED, fontSize: 12, width: 90 }}>
                          Notes:
                        </Text>
                        <Text
                          style={{
                            color: TEXT,
                            fontSize: 12,
                            flex: 1,
                            lineHeight: 18,
                          }}
                        >
                          {server.notes}
                        </Text>
                      </View>
                    ) : null}
                  </View>

                  {/* Actions — split into 2 rows so each button has room */}
                  <View style={{ gap: 8 }}>
                    {/* Row 1: Terminal + Files (primary live-connection actions) */}
                    <View style={{ flexDirection: "row", gap: 8 }}>
                      <TouchableOpacity
                        onPress={() =>
                          router.push(`/terminal?serverId=${server.id}`)
                        }
                        style={{
                          flex: 1,
                          backgroundColor: "#FF00FF25",
                          borderRadius: 10,
                          paddingVertical: 12,
                          flexDirection: "row",
                          alignItems: "center",
                          justifyContent: "center",
                          gap: 6,
                          borderWidth: 1,
                          borderColor: "#FF00FF",
                        }}
                      >
                        <Text style={{ fontSize: 15 }}>🖥️</Text>
                        <Text
                          style={{
                            color: "#FF00FF",
                            fontWeight: "800",
                            fontSize: 13,
                          }}
                        >
                          Terminal
                        </Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        onPress={() =>
                          router.push(`/filemanager?serverId=${server.id}`)
                        }
                        style={{
                          flex: 1,
                          backgroundColor: TEAL + "25",
                          borderRadius: 10,
                          paddingVertical: 12,
                          flexDirection: "row",
                          alignItems: "center",
                          justifyContent: "center",
                          gap: 6,
                          borderWidth: 1,
                          borderColor: TEAL,
                        }}
                      >
                        <Text style={{ fontSize: 15 }}>📁</Text>
                        <Text
                          style={{
                            color: TEAL,
                            fontWeight: "800",
                            fontSize: 13,
                          }}
                        >
                          Files
                        </Text>
                      </TouchableOpacity>
                    </View>

                    {/* Row 2: Copy SSH (wide) + Edit + Delete */}
                    <View style={{ flexDirection: "row", gap: 8 }}>
                      <TouchableOpacity
                        onPress={() => handleCopySSH(server)}
                        style={{
                          flex: 2,
                          backgroundColor: copiedSSH === server.id ? GREEN : TEAL,
                          borderRadius: 10,
                          paddingVertical: 11,
                          flexDirection: "row",
                          alignItems: "center",
                          justifyContent: "center",
                          gap: 6,
                        }}
                      >
                        <Text style={{ fontSize: 14 }}>
                          {copiedSSH === server.id ? "✅" : "🔑"}
                        </Text>
                        <Text
                          style={{
                            color: "#000F1A",
                            fontWeight: "800",
                            fontSize: 12,
                          }}
                        >
                          {copiedSSH === server.id ? "Copied!" : "Copy SSH"}
                        </Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        onPress={() => openEditModal(server)}
                        style={{
                          flex: 1,
                          backgroundColor: CYAN + "25",
                          borderRadius: 10,
                          paddingVertical: 11,
                          borderWidth: 1,
                          borderColor: CYAN,
                          alignItems: "center",
                          justifyContent: "center",
                        }}
                      >
                        <Text
                          style={{ color: CYAN, fontWeight: "800", fontSize: 12 }}
                        >
                          ✏️ Edit
                        </Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        onPress={() => handleDelete(server.id)}
                        style={{
                          flex: 0.6,
                          backgroundColor: RED + "25",
                          borderRadius: 10,
                          paddingVertical: 11,
                          borderWidth: 1,
                          borderColor: RED,
                          alignItems: "center",
                          justifyContent: "center",
                        }}
                      >
                        <Text style={{ color: RED, fontWeight: "800", fontSize: 14 }}>
                          🗑️
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                </View>
              )}
            </View>
          );
        })}
      </ScrollView>

      {/* ── Add/Edit Modal ── */}
      <Modal
        visible={modalVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setModalVisible(false)}
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
                {editingId ? "Edit VPS" : "Add New VPS"}
              </Text>
              <TouchableOpacity onPress={() => setModalVisible(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>

          <ScrollView
            style={{ flex: 1 }}
            contentContainerStyle={{
              padding: 18,
              paddingBottom: insets.bottom + 20,
            }}
          >
            {[
              {
                label: "Nickname *",
                value: nickname,
                setter: setNickname,
                placeholder: "e.g. Production Server",
                keyboard: "default",
              },
              {
                label: "IP Address *",
                value: ip,
                setter: setIp,
                placeholder: "e.g. 192.168.1.100",
                keyboard: "numbers-and-punctuation",
              },
              {
                label: "SSH Username",
                value: sshUsername,
                setter: setSshUsername,
                placeholder: "root",
                keyboard: "default",
              },
              {
                label: "SSH Port",
                value: sshPort,
                setter: setSshPort,
                placeholder: "22",
                keyboard: "number-pad",
              },
              {
                label: "SSH Password",
                value: passwordHint,
                setter: setPasswordHint,
                placeholder: "VPS root password (used for Terminal / Files)",
                keyboard: "default",
                secure: true,
              },
            ].map(({ label, value, setter, placeholder, keyboard, secure }) => (
              <View key={label}>
                <Text
                  style={{
                    color: TEXT,
                    fontSize: 13,
                    fontWeight: "700",
                    marginBottom: 8,
                  }}
                >
                  {label}
                </Text>
                <TextInput
                  placeholder={placeholder}
                  placeholderTextColor={MUTED}
                  value={value}
                  onChangeText={setter}
                  keyboardType={keyboard}
                  secureTextEntry={!!secure}
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
                    marginBottom: 16,
                  }}
                />
              </View>
            ))}

            {/* Current OS picker */}
            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Current OS
            </Text>
            <TouchableOpacity
              onPress={() => setShowOSPicker((v) => !v)}
              style={{
                backgroundColor: CARD,
                borderRadius: 10,
                borderWidth: 1,
                borderColor: BORDER,
                paddingHorizontal: 14,
                paddingVertical: 12,
                marginBottom: showOSPicker || osIsCustom ? 8 : 16,
                flexDirection: "row",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              <Text style={{ color: currentOS || osIsCustom ? TEXT : MUTED, fontSize: 14 }}>
                {osIsCustom
                  ? currentOS
                    ? `Other: ${currentOS}`
                    : "Other (type custom OS below)"
                  : currentOS || "Select OS\u2026"}
              </Text>
              <Text style={{ color: MUTED, fontSize: 14 }}>
                {showOSPicker ? "\u25b2" : "\u25bc"}
              </Text>
            </TouchableOpacity>
            {showOSPicker && (
              <View
                style={{
                  flexDirection: "row",
                  flexWrap: "wrap",
                  gap: 8,
                  marginBottom: 16,
                }}
              >
                {OS_OPTIONS.map((os) => {
                  const isOther = os === "Other";
                  const selected = isOther
                    ? osIsCustom
                    : !osIsCustom && currentOS === os;
                  return (
                    <TouchableOpacity
                      key={os}
                      onPress={() => {
                        if (isOther) {
                          setOsIsCustom(true);
                          setCurrentOS("");
                        } else {
                          setOsIsCustom(false);
                          setCurrentOS(os);
                        }
                        setShowOSPicker(false);
                      }}
                      style={{
                        backgroundColor: selected ? CYAN : CARD,
                        borderRadius: 8,
                        borderWidth: 1,
                        borderColor: selected ? CYAN : BORDER,
                        paddingHorizontal: 12,
                        paddingVertical: 8,
                      }}
                    >
                      <Text style={{ color: selected ? "#000F1A" : TEXT, fontSize: 12, fontWeight: "700" }}>
                        {os}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </View>
            )}
            {osIsCustom && (
              <TextInput
                placeholder="Custom OS name (e.g. NixOS 24.05)"
                placeholderTextColor={MUTED}
                value={currentOS}
                onChangeText={setCurrentOS}
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
                  marginBottom: 16,
                }}
              />
            )}

            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Provider
            </Text>
            <View
              style={{
                flexDirection: "row",
                flexWrap: "wrap",
                gap: 8,
                marginBottom: 16,
              }}
            >
              {PROVIDERS.map((p) => (
                <TouchableOpacity
                  key={p}
                  onPress={() => setProvider(p)}
                  style={{
                    backgroundColor: provider === p ? CYAN : CARD,
                    borderRadius: 8,
                    borderWidth: 1,
                    borderColor: provider === p ? CYAN : BORDER,
                    paddingHorizontal: 12,
                    paddingVertical: 8,
                  }}
                >
                  <Text
                    style={{
                      color: provider === p ? "#000F1A" : TEXT,
                      fontSize: 12,
                      fontWeight: "700",
                    }}
                  >
                    {p}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Status
            </Text>
            <View style={{ flexDirection: "row", gap: 10, marginBottom: 16 }}>
              {STATUS_OPTIONS.map((s) => (
                <TouchableOpacity
                  key={s.label}
                  onPress={() => setStatus(s.label)}
                  style={{
                    flex: 1,
                    backgroundColor: status === s.label ? s.color : CARD,
                    borderRadius: 10,
                    borderWidth: 1,
                    borderColor: status === s.label ? s.color : BORDER,
                    paddingVertical: 10,
                    alignItems: "center",
                  }}
                >
                  <Text
                    style={{
                      color: status === s.label ? "#000F1A" : TEXT,
                      fontSize: 12,
                      fontWeight: "700",
                    }}
                  >
                    {s.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Notes
            </Text>
            <TextInput
              placeholder="Any additional info..."
              placeholderTextColor={MUTED}
              value={notes}
              onChangeText={setNotes}
              multiline
              numberOfLines={4}
              style={{
                backgroundColor: CARD,
                borderRadius: 10,
                borderWidth: 1,
                borderColor: BORDER,
                color: TEXT,
                fontSize: 14,
                paddingHorizontal: 14,
                paddingVertical: 12,
                marginBottom: 24,
                height: 100,
                textAlignVertical: "top",
              }}
            />

            <TouchableOpacity
              onPress={handleSave}
              style={{
                backgroundColor: CYAN,
                borderRadius: 12,
                paddingVertical: 16,
                alignItems: "center",
              }}
            >
              <Text
                style={{ color: "#000F1A", fontWeight: "800", fontSize: 15 }}
              >
                {editingId ? "Save Changes" : "Add VPS"}
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </Modal>

      {/* ── Import Modal ── */}
      <Modal
        visible={importModalVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setImportModalVisible(false)}
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
                📥 Import VPS Data
              </Text>
              <TouchableOpacity onPress={() => setImportModalVisible(false)}>
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>

          <ScrollView
            style={{ flex: 1 }}
            contentContainerStyle={{
              padding: 18,
              paddingBottom: insets.bottom + 20,
            }}
          >
            <View
              style={{
                backgroundColor: CYAN + "15",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: CYAN + "40",
                padding: 14,
                marginBottom: 20,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 18 }}>💡</Text>
              <Text
                style={{ color: CYAN, fontSize: 12, flex: 1, lineHeight: 18 }}
              >
                Paste the JSON from a previous "Export" here. You can choose to
                merge (keep existing) or replace all servers.
              </Text>
            </View>

            <Text
              style={{
                color: TEXT,
                fontSize: 13,
                fontWeight: "700",
                marginBottom: 8,
              }}
            >
              Paste Export JSON
            </Text>
            <TextInput
              placeholder={'{\n  "servers": [...]\n}'}
              placeholderTextColor={MUTED}
              value={importText}
              onChangeText={setImportText}
              multiline
              style={{
                backgroundColor: CARD,
                borderRadius: 10,
                borderWidth: 1,
                borderColor: BORDER,
                color: TEXT,
                fontSize: 12,
                fontFamily: "monospace",
                paddingHorizontal: 14,
                paddingVertical: 12,
                marginBottom: 20,
                height: 220,
                textAlignVertical: "top",
              }}
            />

            <TouchableOpacity
              onPress={handleImport}
              style={{
                backgroundColor: CYAN,
                borderRadius: 12,
                paddingVertical: 16,
                alignItems: "center",
              }}
            >
              <Text
                style={{ color: "#000F1A", fontWeight: "800", fontSize: 15 }}
              >
                Import & Choose Action
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </Modal>

      {/* ── Backend Settings Modal ── */}
      <Modal
        visible={backendSettingsVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setBackendSettingsVisible(false)}
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
                ⚙️ Backend Settings
              </Text>
              <TouchableOpacity
                onPress={() => setBackendSettingsVisible(false)}
              >
                <Text style={{ color: MUTED, fontSize: 28 }}>×</Text>
              </TouchableOpacity>
            </View>
          </View>

          <ScrollView
            style={{ flex: 1 }}
            contentContainerStyle={{
              padding: 18,
              paddingBottom: insets.bottom + 20,
            }}
          >
            <View
              style={{
                backgroundColor: CYAN + "15",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: CYAN + "40",
                padding: 14,
                marginBottom: 20,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 18 }}>💡</Text>
              <Text
                style={{ color: CYAN, fontSize: 12, flex: 1, lineHeight: 18 }}
              >
                The SSH Terminal feature requires a self-hosted backend. Install
                it on any VPS using the one-liner below, then enter the
                WebSocket URL here.
              </Text>
            </View>

            <View
              style={{
                backgroundColor: CARD,
                borderRadius: 12,
                borderWidth: 1,
                borderColor: BORDER,
                padding: 14,
                marginBottom: 20,
              }}
            >
              <Text
                style={{
                  color: TEXT,
                  fontSize: 13,
                  fontWeight: "700",
                  marginBottom: 8,
                }}
              >
                📋 Quick Setup
              </Text>
              <Text
                style={{
                  color: MUTED,
                  fontSize: 12,
                  lineHeight: 18,
                  marginBottom: 12,
                }}
              >
                SSH into any VPS and run:
              </Text>
              <View
                style={{
                  backgroundColor: BG,
                  borderRadius: 8,
                  padding: 10,
                  borderWidth: 1,
                  borderColor: BORDER,
                }}
              >
                <Text
                  style={{
                    color: CYAN,
                    fontFamily: "monospace",
                    fontSize: 10,
                    lineHeight: 14,
                  }}
                  selectable
                >
                  {BACKEND_SETUP_SCRIPT}
                </Text>
              </View>
              <TouchableOpacity
                onPress={handleCopySetupScript}
                style={{
                  marginTop: 10,
                  backgroundColor: copiedSetup ? GREEN : CYAN,
                  borderRadius: 10,
                  paddingVertical: 12,
                  flexDirection: "row",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 8,
                }}
              >
                <Text style={{ fontSize: 15 }}>
                  {copiedSetup ? "✅" : "📋"}
                </Text>
                <Text
                  style={{
                    color: "#000F1A",
                    fontWeight: "800",
                    fontSize: 14,
                  }}
                >
                  {copiedSetup ? "Copied!" : "Copy Setup Command"}
                </Text>
              </TouchableOpacity>
              <Text
                style={{
                  color: MUTED,
                  fontSize: 11,
                  marginTop: 8,
                  fontStyle: "italic",
                }}
              >
                Backend will start on port 8000
              </Text>
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
                marginBottom: 8,
              }}
            />
            <Text
              style={{
                color: MUTED,
                fontSize: 11,
                marginBottom: 24,
              }}
            >
              Example: ws://123.45.67.89:8000 or http://your-domain.com:8000
            </Text>

            <View style={{ flexDirection: "row", gap: 10 }}>
              <TouchableOpacity
                onPress={handleTestBackend}
                disabled={testingBackend}
                style={{
                  flex: 1,
                  backgroundColor: testingBackend ? CARD : TEAL + "25",
                  borderRadius: 12,
                  paddingVertical: 16,
                  alignItems: "center",
                  borderWidth: 1,
                  borderColor: TEAL,
                }}
              >
                <Text style={{ color: TEAL, fontWeight: "800", fontSize: 14 }}>
                  {testingBackend ? "Testing…" : "🔌 Test Backend"}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                onPress={saveBackendUrl}
                style={{
                  flex: 1,
                  backgroundColor: CYAN,
                  borderRadius: 12,
                  paddingVertical: 16,
                  alignItems: "center",
                }}
              >
                <Text style={{ color: "#000F1A", fontWeight: "800", fontSize: 14 }}>
                  Save URL
                </Text>
              </TouchableOpacity>
            </View>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}
