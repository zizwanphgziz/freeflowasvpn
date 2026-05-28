import { useState, useCallback, useEffect } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Modal,
} from "react-native";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { osData } from "../../data/osData";
import { useTheme } from "@/utils/ThemeContext";

const LOGO =
  "https://dtvoeevhaseb5.cloudfront.net/user-uploads/f8f5b2b0-a11f-4713-8f86-06409841e8a9.jpg";
const HISTORY_KEY = "@freeflow_history";
const FAVORITES_KEY = "@freeflow_favorites";

const CHECKLIST_ITEMS = [
  "Backup all important data",
  "Note current SSH port (if non-standard)",
  "Save current IP configuration",
  "Document installed software",
  "Export database dumps",
  "Keep VPS provider credentials handy",
];

export default function RebuildScreen() {
  const insets = useSafeAreaInsets();
  const { theme } = useTheme();
  const {
    BG,
    CARD,
    BORDER,
    CYAN,
    BLUE,
    TEAL,
    TEXT,
    MUTED,
    WARN,
    GREEN,
    STATUS_BAR,
    SCRIPT_BG,
    SCRIPT_TEXT,
  } = theme;

  const [search, setSearch] = useState("");
  const [tab, setTab] = useState("linux");
  const [selected, setSelected] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const [favorites, setFavorites] = useState([]);
  const [builderOpen, setBuilderOpen] = useState(false);
  const [customPassword, setCustomPassword] = useState("");
  const [customSSHPort, setCustomSSHPort] = useState("");
  const [customTimezone, setCustomTimezone] = useState("");
  const [customLang, setCustomLang] = useState("");
  const [checklistOpen, setChecklistOpen] = useState(false);
  const [checkedItems, setCheckedItems] = useState([]);

  useEffect(() => {
    loadFavorites();
  }, []);

  const loadFavorites = async () => {
    try {
      const data = await AsyncStorage.getItem(FAVORITES_KEY);
      if (data) setFavorites(JSON.parse(data));
    } catch (e) {
      console.error("Failed to load favorites", e);
    }
  };

  const filtered = osData.filter(
    (os) =>
      os.category === tab &&
      (search === "" || os.name.toLowerCase().includes(search.toLowerCase())),
  );

  const saveToHistory = async (script, label) => {
    try {
      const historyData = await AsyncStorage.getItem(HISTORY_KEY);
      const history = historyData ? JSON.parse(historyData) : [];
      const updated = [
        { script, label, timestamp: Date.now() },
        ...history.filter((h) => h.script !== script),
      ].slice(0, 100);
      await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(updated));
    } catch (e) {
      console.error("Failed to save history", e);
    }
  };

  const handleCopy = useCallback(async (script, id, label) => {
    await Clipboard.setStringAsync(script);
    await saveToHistory(script, label);
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2200);
  }, []);

  const toggleFavorite = async (script, label) => {
    const isFav = favorites.some((f) => f.script === script);
    const updated = isFav
      ? favorites.filter((f) => f.script !== script)
      : [...favorites, { script, label, favoritedAt: Date.now() }];
    await AsyncStorage.setItem(FAVORITES_KEY, JSON.stringify(updated));
    setFavorites(updated);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const isFavorited = (script) => favorites.some((f) => f.script === script);

  const handleVersionSelect = useCallback(
    (os, ver) => {
      if (
        selected?.os?.id === os.id &&
        selected?.version?.version === ver.version
      ) {
        setSelected(null);
      } else {
        setSelected({ os, version: ver });
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      }
    },
    [selected],
  );

  const buildCustomScript = () => {
    const base =
      "bash <(curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh)";
    const flags = [
      customPassword && `--password ${customPassword}`,
      customSSHPort && `--ssh-port ${customSSHPort}`,
      customTimezone && `--timezone ${customTimezone}`,
      customLang && `--lang ${customLang}`,
    ].filter(Boolean);
    return [base, ...flags, "&& reboot"].join(" ");
  };

  const toggleChecklistItem = (idx) =>
    setCheckedItems((prev) =>
      prev.includes(idx) ? prev.filter((i) => i !== idx) : [...prev, idx],
    );

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
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: 10,
          }}
        >
          <Image
            source={{ uri: LOGO }}
            style={{ width: 160, height: 46 }}
            contentFit="contain"
          />
          <TouchableOpacity
            onPress={() => setChecklistOpen(true)}
            style={{
              backgroundColor: WARN + "25",
              borderRadius: 8,
              paddingHorizontal: 10,
              paddingVertical: 6,
              borderWidth: 1,
              borderColor: WARN,
            }}
          >
            <Text style={{ color: WARN, fontWeight: "800", fontSize: 11 }}>
              📋 Checklist
            </Text>
          </TouchableOpacity>
        </View>

        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            backgroundColor: CARD,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: BORDER,
            paddingHorizontal: 14,
            height: 44,
          }}
        >
          <Text style={{ fontSize: 15, marginRight: 8 }}>🔍</Text>
          <TextInput
            placeholder="Search distro..."
            placeholderTextColor={MUTED}
            value={search}
            onChangeText={setSearch}
            style={{ flex: 1, color: TEXT, fontSize: 14 }}
          />
          {search.length > 0 && (
            <TouchableOpacity onPress={() => setSearch("")}>
              <Text style={{ color: MUTED, fontSize: 20 }}>×</Text>
            </TouchableOpacity>
          )}
        </View>

        <View style={{ flexDirection: "row", gap: 10, marginTop: 12 }}>
          {[
            { key: "linux", label: "🐧  Linux" },
            { key: "windows", label: "🪟  Windows" },
          ].map(({ key, label }) => (
            <TouchableOpacity
              key={key}
              onPress={() => {
                setTab(key);
                setSelected(null);
              }}
              style={{
                flex: 1,
                paddingVertical: 10,
                borderRadius: 10,
                backgroundColor: tab === key ? CYAN : CARD,
                borderWidth: 1,
                borderColor: tab === key ? CYAN : BORDER,
                alignItems: "center",
              }}
            >
              <Text
                style={{
                  color: tab === key ? "#000F1A" : TEXT,
                  fontWeight: "700",
                  fontSize: 13,
                }}
              >
                {label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingBottom: insets.bottom + 90,
        }}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View
          style={{
            backgroundColor: WARN + "18",
            borderRadius: 10,
            borderWidth: 1,
            borderColor: WARN + "50",
            padding: 12,
            flexDirection: "row",
            gap: 10,
            marginBottom: 14,
            alignItems: "flex-start",
          }}
        >
          <Text style={{ fontSize: 16 }}>⚠️</Text>
          <Text style={{ color: WARN, fontSize: 12, flex: 1, lineHeight: 18 }}>
            Scripts completely wipe the OS. Always back up data before running.
          </Text>
        </View>

        {/* Script Builder */}
        <TouchableOpacity
          activeOpacity={0.9}
          onPress={() => setBuilderOpen(!builderOpen)}
          style={{
            backgroundColor: builderOpen ? BLUE + "18" : CARD,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: builderOpen ? BLUE : BORDER,
            padding: 14,
            marginBottom: 14,
            flexDirection: "row",
            alignItems: "center",
            gap: 12,
          }}
        >
          <View
            style={{
              width: 38,
              height: 38,
              borderRadius: 10,
              backgroundColor: BLUE + "25",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Text style={{ fontSize: 18 }}>🛠️</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ color: TEXT, fontWeight: "700", fontSize: 14 }}>
              Advanced Script Builder
            </Text>
            <Text style={{ color: MUTED, fontSize: 11, marginTop: 2 }}>
              Custom password, SSH port, timezone, lang
            </Text>
          </View>
          <Text style={{ color: MUTED, fontSize: 16 }}>
            {builderOpen ? "▲" : "▼"}
          </Text>
        </TouchableOpacity>

        {builderOpen && (
          <View
            style={{
              backgroundColor: CARD,
              borderRadius: 12,
              borderWidth: 1,
              borderColor: BORDER,
              padding: 14,
              marginBottom: 14,
            }}
          >
            {[
              {
                ph: "--password YOUR_PASS",
                val: customPassword,
                set: setCustomPassword,
                kb: "default",
              },
              {
                ph: "--ssh-port 2222",
                val: customSSHPort,
                set: setCustomSSHPort,
                kb: "number-pad",
              },
              {
                ph: "--timezone America/New_York",
                val: customTimezone,
                set: setCustomTimezone,
                kb: "default",
              },
              {
                ph: "--lang en_US",
                val: customLang,
                set: setCustomLang,
                kb: "default",
              },
            ].map(({ ph, val, set, kb }) => (
              <TextInput
                key={ph}
                placeholder={ph}
                placeholderTextColor={MUTED}
                value={val}
                onChangeText={set}
                keyboardType={kb}
                style={{
                  backgroundColor: BG,
                  borderRadius: 8,
                  borderWidth: 1,
                  borderColor: BORDER,
                  color: TEXT,
                  fontSize: 12,
                  paddingHorizontal: 12,
                  paddingVertical: 10,
                  marginBottom: 8,
                }}
              />
            ))}
            <Text style={{ color: MUTED, fontSize: 11, marginBottom: 8 }}>
              Preview:
            </Text>
            <View
              style={{
                backgroundColor: SCRIPT_BG,
                borderRadius: 8,
                borderWidth: 1,
                borderColor: TEAL + "40",
                padding: 10,
                marginBottom: 10,
              }}
            >
              <Text
                style={{
                  color: SCRIPT_TEXT,
                  fontFamily: "monospace",
                  fontSize: 10,
                  lineHeight: 16,
                }}
              >
                {buildCustomScript()}
              </Text>
            </View>
            <TouchableOpacity
              onPress={() =>
                handleCopy(
                  buildCustomScript(),
                  "custom-builder",
                  "Custom Script Builder",
                )
              }
              style={{
                backgroundColor: copiedId === "custom-builder" ? GREEN : BLUE,
                borderRadius: 8,
                paddingVertical: 10,
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "center",
                gap: 6,
              }}
            >
              <Text style={{ fontSize: 14 }}>
                {copiedId === "custom-builder" ? "✅" : "📋"}
              </Text>
              <Text
                style={{ color: "#000F1A", fontWeight: "800", fontSize: 12 }}
              >
                {copiedId === "custom-builder"
                  ? "Copied!"
                  : "Copy Custom Script"}
              </Text>
            </TouchableOpacity>
          </View>
        )}

        {filtered.length === 0 && (
          <View style={{ alignItems: "center", paddingTop: 48 }}>
            <Text style={{ fontSize: 44, marginBottom: 12 }}>🔍</Text>
            <Text style={{ color: MUTED, fontSize: 15 }}>
              No results for "{search}"
            </Text>
          </View>
        )}

        {filtered.map((os) => {
          const isExpanded = selected?.os?.id === os.id;
          return (
            <View key={os.id} style={{ marginBottom: 10 }}>
              <TouchableOpacity
                activeOpacity={0.8}
                onPress={() => {
                  if (isExpanded) {
                    setSelected(null);
                  } else {
                    setSelected({ os, version: null });
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  }
                }}
                style={{
                  backgroundColor: isExpanded ? CYAN + "18" : CARD,
                  borderRadius: 14,
                  borderWidth: 1,
                  borderColor: isExpanded ? CYAN : BORDER,
                  padding: 14,
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <View
                  style={{
                    width: 46,
                    height: 46,
                    borderRadius: 12,
                    backgroundColor: os.color + "28",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Text style={{ fontSize: 24 }}>{os.icon}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text
                    style={{ color: TEXT, fontWeight: "700", fontSize: 15 }}
                  >
                    {os.name}
                  </Text>
                  <Text style={{ color: MUTED, fontSize: 12, marginTop: 2 }}>
                    {os.description}
                  </Text>
                </View>
                <View style={{ alignItems: "flex-end", gap: 5 }}>
                  <View
                    style={{
                      backgroundColor: CYAN + "25",
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 3,
                    }}
                  >
                    <Text
                      style={{ color: CYAN, fontSize: 11, fontWeight: "700" }}
                    >
                      {os.versions.length}v
                    </Text>
                  </View>
                  <Text style={{ color: MUTED, fontSize: 16 }}>
                    {isExpanded ? "▲" : "▼"}
                  </Text>
                </View>
              </TouchableOpacity>

              {isExpanded && (
                <View
                  style={{
                    backgroundColor: CARD,
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: BORDER,
                    marginTop: 4,
                    overflow: "hidden",
                  }}
                >
                  {os.versions.map((ver, idx) => {
                    const isSel = selected?.version?.version === ver.version;
                    const copyId = `${os.id}-${ver.version}`;
                    const label = `${os.name} ${ver.version}`;
                    const isFav = isFavorited(ver.script);
                    return (
                      <View key={ver.version}>
                        <TouchableOpacity
                          activeOpacity={0.7}
                          onPress={() => handleVersionSelect(os, ver)}
                          style={{
                            flexDirection: "row",
                            alignItems: "center",
                            padding: 14,
                            backgroundColor: isSel
                              ? CYAN + "15"
                              : "transparent",
                          }}
                        >
                          <View
                            style={{
                              width: 8,
                              height: 8,
                              borderRadius: 4,
                              backgroundColor: isSel ? CYAN : MUTED,
                              marginRight: 12,
                            }}
                          />
                          <View style={{ flex: 1 }}>
                            <Text
                              style={{
                                color: TEXT,
                                fontWeight: "600",
                                fontSize: 14,
                              }}
                            >
                              {label}
                            </Text>
                            {ver.codename && (
                              <Text
                                style={{
                                  color: MUTED,
                                  fontSize: 12,
                                  marginTop: 1,
                                }}
                              >
                                {ver.codename}
                              </Text>
                            )}
                          </View>
                          <TouchableOpacity
                            onPress={() => toggleFavorite(ver.script, label)}
                          >
                            <Text style={{ fontSize: 20, marginRight: 8 }}>
                              {isFav ? "⭐" : "☆"}
                            </Text>
                          </TouchableOpacity>
                          <Text
                            style={{
                              color: isSel ? CYAN : MUTED,
                              fontWeight: isSel ? "700" : "400",
                              fontSize: 13,
                            }}
                          >
                            {isSel ? "Selected ✓" : "›"}
                          </Text>
                        </TouchableOpacity>
                        {isSel && (
                          <View
                            style={{ paddingHorizontal: 14, paddingBottom: 14 }}
                          >
                            <View
                              style={{
                                backgroundColor: SCRIPT_BG,
                                borderRadius: 10,
                                borderWidth: 1,
                                borderColor: TEAL + "50",
                                padding: 12,
                              }}
                            >
                              <Text
                                style={{
                                  color: SCRIPT_TEXT,
                                  fontFamily: "monospace",
                                  fontSize: 11,
                                  lineHeight: 18,
                                }}
                              >
                                {ver.script}
                              </Text>
                            </View>
                            <TouchableOpacity
                              onPress={() =>
                                handleCopy(ver.script, copyId, label)
                              }
                              style={{
                                marginTop: 10,
                                backgroundColor:
                                  copiedId === copyId ? GREEN : CYAN,
                                borderRadius: 10,
                                paddingVertical: 13,
                                alignItems: "center",
                                flexDirection: "row",
                                justifyContent: "center",
                                gap: 8,
                              }}
                            >
                              <Text style={{ fontSize: 16 }}>
                                {copiedId === copyId ? "✅" : "📋"}
                              </Text>
                              <Text
                                style={{
                                  color: "#000F1A",
                                  fontWeight: "800",
                                  fontSize: 14,
                                }}
                              >
                                {copiedId === copyId
                                  ? "Copied!"
                                  : "Copy Command"}
                              </Text>
                            </TouchableOpacity>
                          </View>
                        )}
                        {idx < os.versions.length - 1 && (
                          <View
                            style={{
                              height: 1,
                              backgroundColor: BORDER,
                              marginHorizontal: 14,
                            }}
                          />
                        )}
                      </View>
                    );
                  })}
                </View>
              )}
            </View>
          );
        })}
      </ScrollView>

      {/* Checklist Modal */}
      <Modal
        visible={checklistOpen}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setChecklistOpen(false)}
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
                Pre-Rebuild Checklist
              </Text>
              <TouchableOpacity onPress={() => setChecklistOpen(false)}>
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
                backgroundColor: WARN + "18",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: WARN + "40",
                padding: 14,
                marginBottom: 20,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 20 }}>⚠️</Text>
              <Text
                style={{ color: WARN, fontSize: 13, flex: 1, lineHeight: 20 }}
              >
                Complete these steps before running any rebuild script.
              </Text>
            </View>
            {CHECKLIST_ITEMS.map((item, idx) => {
              const isChecked = checkedItems.includes(idx);
              return (
                <TouchableOpacity
                  key={idx}
                  onPress={() => toggleChecklistItem(idx)}
                  style={{
                    backgroundColor: isChecked ? GREEN + "15" : CARD,
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: isChecked ? GREEN : BORDER,
                    padding: 16,
                    marginBottom: 10,
                    flexDirection: "row",
                    alignItems: "center",
                    gap: 12,
                  }}
                >
                  <View
                    style={{
                      width: 28,
                      height: 28,
                      borderRadius: 14,
                      backgroundColor: isChecked ? GREEN : CARD,
                      borderWidth: 2,
                      borderColor: isChecked ? GREEN : BORDER,
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    {isChecked && (
                      <Text
                        style={{
                          color: "#fff",
                          fontSize: 16,
                          fontWeight: "700",
                        }}
                      >
                        ✓
                      </Text>
                    )}
                  </View>
                  <Text
                    style={{
                      color: isChecked ? GREEN : TEXT,
                      fontSize: 14,
                      fontWeight: "600",
                      flex: 1,
                    }}
                  >
                    {item}
                  </Text>
                </TouchableOpacity>
              );
            })}
            <View
              style={{
                backgroundColor: CYAN + "12",
                borderRadius: 12,
                borderWidth: 1,
                borderColor: CYAN + "35",
                padding: 14,
                marginTop: 10,
                flexDirection: "row",
                gap: 10,
              }}
            >
              <Text style={{ fontSize: 18 }}>💡</Text>
              <Text
                style={{ color: CYAN, fontSize: 12, flex: 1, lineHeight: 18 }}
              >
                Once checked off, head back to copy your rebuild command!
              </Text>
            </View>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}
