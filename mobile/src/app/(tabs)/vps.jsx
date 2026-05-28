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
  const [expandedId, setExpandedId] = useState(null);

  // Form state
  const [nickname, setNickname] = useState("");
  const [ip, setIp] = useState("");
  const [provider, setProvider] = useState("Vultr");
  const [currentOS, setCurrentOS] = useState("");
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
    setProvider("Vultr");
    setCurrentOS("");
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
    setProvider(server.provider);
    setCurrentOS(server.currentOS);
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
    const newServer = {
      id: editingId || Date.now().toString(),
      nickname: nickname.trim(),
      ip: ip.trim(),
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

  const handleCopySSH = async (serverIp, id) => {
    await Clipboard.setStringAsync(`ssh root@${serverIp}`);
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedSSH(id);
    setTimeout(() => setCopiedSSH(null), 2000);
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
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Text style={{ color: MUTED, fontSize: 13 }}>My VPS Servers</Text>
          <View style={{ flexDirection: "row", gap: 8 }}>
            <TouchableOpacity
              onPress={() => setBackendSettingsVisible(true)}
              style={{
                backgroundColor: CARD,
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 7,
                borderWidth: 1,
                borderColor: BORDER,
              }}
            >
              <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
                ⚙️ Backend
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => setImportModalVisible(true)}
              style={{
                backgroundColor: CARD,
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 7,
                borderWidth: 1,
                borderColor: BORDER,
              }}
            >
              <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
                📥 Import
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={handleExport}
              style={{
                backgroundColor: CARD,
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 7,
                borderWidth: 1,
                borderColor: BORDER,
              }}
            >
              <Text style={{ color: TEXT, fontSize: 12, fontWeight: "700" }}>
                📤 Export
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={openAddModal}
              style={{
                backgroundColor: CYAN,
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 7,
                flexDirection: "row",
                alignItems: "center",
                gap: 4,
              }}
            >
              <Text
                style={{ color: "#000F1A", fontWeight: "800", fontSize: 12 }}
              >
                ➕ Add
              </Text>
            </TouchableOpacity>
          </View>
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
              Tap "Add" to start tracking your servers, or "Import" to restore a
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

                  {/* Actions */}
                  <View style={{ flexDirection: "row", gap: 8 }}>
                    <TouchableOpacity
                      onPress={() =>
                        router.push(`/terminal?serverId=${server.id}`)
                      }
                      style={{
                        flex: 1,
                        backgroundColor: "#FF00FF25",
                        borderRadius: 10,
                        paddingVertical: 11,
                        flexDirection: "row",
                        alignItems: "center",
                        justifyContent: "center",
                        gap: 6,
                        borderWidth: 1,
                        borderColor: "#FF00FF",
                      }}
                    >
                      <Text style={{ fontSize: 14 }}>🖥️</Text>
                      <Text
                        style={{
                          color: "#FF00FF",
                          fontWeight: "800",
                          fontSize: 12,
                        }}
                      >
                        Terminal
                      </Text>
                    </TouchableOpacity>
                    {/* File Manager button */}
                    <TouchableOpacity
                      onPress={() =>
                        router.push(`/filemanager?serverId=${server.id}`)
                      }
                      style={{
                        flex: 1,
                        backgroundColor: TEAL + "25",
                        borderRadius: 10,
                        paddingVertical: 11,
                        flexDirection: "row",
                        alignItems: "center",
                        justifyContent: "center",
                        gap: 6,
                        borderWidth: 1,
                        borderColor: TEAL,
                      }}
                    >
                      <Text style={{ fontSize: 14 }}>📁</Text>
                      <Text
                        style={{
                          color: TEAL,
                          fontWeight: "800",
                          fontSize: 12,
                        }}
                      >
                        Files
                      </Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      onPress={() => handleCopySSH(server.ip, server.id)}
                      style={{
                        flex: 1,
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
                        backgroundColor: CYAN + "25",
                        borderRadius: 10,
                        paddingHorizontal: 14,
                        paddingVertical: 11,
                        borderWidth: 1,
                        borderColor: CYAN,
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
                        backgroundColor: RED + "25",
                        borderRadius: 10,
                        paddingHorizontal: 14,
                        paddingVertical: 11,
                        borderWidth: 1,
                        borderColor: RED,
                      }}
                    >
                      <Text
                        style={{ color: RED, fontWeight: "800", fontSize: 12 }}
                      >
                        🗑️
                      </Text>
                    </TouchableOpacity>
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
                label: "Current OS",
                value: currentOS,
                setter: setCurrentOS,
                placeholder: "e.g. Ubuntu 24.04",
                keyboard: "default",
              },
              {
                label: "Password Hint",
                value: passwordHint,
                setter: setPasswordHint,
                placeholder: "e.g. usual+123",
                keyboard: "default",
              },
            ].map(({ label, value, setter, placeholder, keyboard }) => (
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
                >
                  curl -fsSL
                  https://raw.githubusercontent.com/zizwanphgziz/freeflowonelinerrebuildvps/devin/initial-setup/setup.sh
                  | bash
                </Text>
              </View>
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

            <TouchableOpacity
              onPress={saveBackendUrl}
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
                Save Backend URL
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}
