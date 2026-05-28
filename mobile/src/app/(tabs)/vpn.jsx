import { useState, useCallback, useEffect } from "react";
import { View, Text, ScrollView, TouchableOpacity } from "react-native";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { vpnCategories } from "../../data/vpnTools";
import { useTheme } from "@/utils/ThemeContext";

const LOGO =
  "https://dtvoeevhaseb5.cloudfront.net/user-uploads/f8f5b2b0-a11f-4713-8f86-06409841e8a9.jpg";
const HISTORY_KEY = "@freeflow_history";
const FAVORITES_KEY = "@freeflow_favorites";

export default function VpnScreen() {
  const insets = useSafeAreaInsets();
  const { theme } = useTheme();
  const {
    BG,
    CARD,
    BORDER,
    CYAN,
    TEAL,
    TEXT,
    MUTED,
    STATUS_BAR,
    SCRIPT_BG,
    SCRIPT_TEXT,
  } = theme;

  const [expandedCat, setExpandedCat] = useState(null);
  const [expandedTool, setExpandedTool] = useState(null);
  const [copiedId, setCopiedId] = useState(null);
  const [favorites, setFavorites] = useState([]);

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

  const saveToHistory = async (script, label) => {
    try {
      const historyData = await AsyncStorage.getItem(HISTORY_KEY);
      const history = historyData ? JSON.parse(historyData) : [];
      const newEntry = { script, label, timestamp: Date.now() };
      const updated = [
        newEntry,
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
    let updated;
    if (isFav) {
      updated = favorites.filter((f) => f.script !== script);
    } else {
      updated = [...favorites, { script, label, favoritedAt: Date.now() }];
    }
    await AsyncStorage.setItem(FAVORITES_KEY, JSON.stringify(updated));
    setFavorites(updated);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const isFavorited = (script) => favorites.some((f) => f.script === script);

  const toggleCat = useCallback((id) => {
    setExpandedCat((prev) => (prev === id ? null : id));
    setExpandedTool(null);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, []);

  const toggleTool = useCallback((id) => {
    setExpandedTool((prev) => (prev === id ? null : id));
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, []);

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
          style={{ width: 180, height: 52, marginBottom: 6 }}
          contentFit="contain"
        />
        <Text style={{ color: MUTED, fontSize: 13 }}>
          VPN Autoscript Installers
        </Text>

        {/* Stats row */}
        <View style={{ flexDirection: "row", gap: 10, marginTop: 14 }}>
          {[
            { label: "Categories", value: vpnCategories.length, icon: "📂" },
            {
              label: "Tools",
              value: vpnCategories.reduce((a, c) => a + c.tools.length, 0),
              icon: "🛠️",
            },
            { label: "One-Click", value: "100%", icon: "✅" },
          ].map(({ label, value, icon }) => (
            <View
              key={label}
              style={{
                flex: 1,
                backgroundColor: CARD,
                borderRadius: 12,
                borderWidth: 1,
                borderColor: BORDER,
                padding: 12,
                alignItems: "center",
              }}
            >
              <Text style={{ fontSize: 20, marginBottom: 4 }}>{icon}</Text>
              <Text style={{ color: CYAN, fontWeight: "800", fontSize: 16 }}>
                {value}
              </Text>
              <Text style={{ color: MUTED, fontSize: 10, marginTop: 2 }}>
                {label}
              </Text>
            </View>
          ))}
        </View>
      </View>

      {/* List */}
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingBottom: insets.bottom + 90,
        }}
        showsVerticalScrollIndicator={false}
      >
        {vpnCategories.map((cat) => {
          const isCatOpen = expandedCat === cat.id;
          return (
            <View key={cat.id} style={{ marginBottom: 10 }}>
              {/* Category header */}
              <TouchableOpacity
                activeOpacity={0.8}
                onPress={() => toggleCat(cat.id)}
                style={{
                  backgroundColor: isCatOpen ? cat.color + "20" : CARD,
                  borderRadius: 14,
                  borderWidth: 1,
                  borderColor: isCatOpen ? cat.color : BORDER,
                  padding: 16,
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
                    backgroundColor: cat.color + "25",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <Text style={{ fontSize: 24 }}>{cat.icon}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text
                    style={{ color: TEXT, fontWeight: "700", fontSize: 15 }}
                  >
                    {cat.name}
                  </Text>
                  <Text style={{ color: MUTED, fontSize: 12, marginTop: 2 }}>
                    {cat.tools.length} installer
                    {cat.tools.length !== 1 ? "s" : ""}
                  </Text>
                </View>
                <View
                  style={{
                    backgroundColor: cat.color + "25",
                    borderRadius: 8,
                    paddingHorizontal: 10,
                    paddingVertical: 5,
                    marginRight: 8,
                  }}
                >
                  <Text
                    style={{
                      color: cat.color,
                      fontWeight: "700",
                      fontSize: 12,
                    }}
                  >
                    {cat.tools.length}
                  </Text>
                </View>
                <Text style={{ color: MUTED, fontSize: 16 }}>
                  {isCatOpen ? "▲" : "▼"}
                </Text>
              </TouchableOpacity>

              {/* Tools inside category */}
              {isCatOpen && (
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
                  {cat.tools.map((tool, idx) => {
                    const isToolOpen = expandedTool === tool.id;
                    const copyId = tool.id;
                    const isFav = isFavorited(tool.script);
                    return (
                      <View key={tool.id}>
                        <TouchableOpacity
                          activeOpacity={0.75}
                          onPress={() => toggleTool(tool.id)}
                          style={{
                            padding: 14,
                            backgroundColor: isToolOpen
                              ? cat.color + "12"
                              : "transparent",
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
                              backgroundColor: cat.color + "20",
                              alignItems: "center",
                              justifyContent: "center",
                            }}
                          >
                            <Text style={{ fontSize: 18 }}>{tool.icon}</Text>
                          </View>
                          <View style={{ flex: 1 }}>
                            <Text
                              style={{
                                color: TEXT,
                                fontWeight: "600",
                                fontSize: 13,
                              }}
                            >
                              {tool.name}
                            </Text>
                            <Text
                              style={{
                                color: MUTED,
                                fontSize: 11,
                                marginTop: 2,
                                lineHeight: 16,
                              }}
                            >
                              {tool.description}
                            </Text>
                          </View>
                          <TouchableOpacity
                            onPress={() =>
                              toggleFavorite(tool.script, tool.name)
                            }
                          >
                            <Text style={{ fontSize: 20, marginRight: 8 }}>
                              {isFav ? "⭐" : "☆"}
                            </Text>
                          </TouchableOpacity>
                          <Text style={{ color: MUTED, fontSize: 16 }}>
                            {isToolOpen ? "▲" : "▼"}
                          </Text>
                        </TouchableOpacity>

                        {/* Script & copy */}
                        {isToolOpen && (
                          <View
                            style={{ paddingHorizontal: 14, paddingBottom: 14 }}
                          >
                            {/* OS Requirement Cards */}
                            {(tool.recommendedOS ||
                              tool.supportedOS ||
                              tool.minRam ||
                              tool.notes) && (
                              <View
                                style={{
                                  backgroundColor: cat.color + "10",
                                  borderRadius: 10,
                                  borderWidth: 1,
                                  borderColor: cat.color + "35",
                                  padding: 12,
                                  marginBottom: 10,
                                  gap: 6,
                                }}
                              >
                                {tool.recommendedOS && (
                                  <View
                                    style={{
                                      flexDirection: "row",
                                      gap: 8,
                                      alignItems: "flex-start",
                                    }}
                                  >
                                    <Text style={{ fontSize: 13 }}>🎯</Text>
                                    <View style={{ flex: 1 }}>
                                      <Text
                                        style={{
                                          color: cat.color,
                                          fontSize: 10,
                                          fontWeight: "800",
                                          marginBottom: 2,
                                        }}
                                      >
                                        RECOMMENDED OS
                                      </Text>
                                      <Text
                                        style={{
                                          color: TEXT,
                                          fontSize: 12,
                                          fontWeight: "600",
                                        }}
                                      >
                                        {tool.recommendedOS}
                                      </Text>
                                    </View>
                                  </View>
                                )}
                                {tool.supportedOS && (
                                  <View
                                    style={{
                                      flexDirection: "row",
                                      gap: 8,
                                      alignItems: "flex-start",
                                    }}
                                  >
                                    <Text style={{ fontSize: 13 }}>✅</Text>
                                    <View style={{ flex: 1 }}>
                                      <Text
                                        style={{
                                          color: MUTED,
                                          fontSize: 10,
                                          fontWeight: "800",
                                          marginBottom: 2,
                                        }}
                                      >
                                        SUPPORTED OS
                                      </Text>
                                      <Text
                                        style={{
                                          color: MUTED,
                                          fontSize: 11,
                                          lineHeight: 16,
                                        }}
                                      >
                                        {tool.supportedOS}
                                      </Text>
                                    </View>
                                  </View>
                                )}
                                {tool.minRam && (
                                  <View
                                    style={{
                                      flexDirection: "row",
                                      gap: 8,
                                      alignItems: "center",
                                    }}
                                  >
                                    <Text style={{ fontSize: 13 }}>💾</Text>
                                    <View style={{ flex: 1 }}>
                                      <Text
                                        style={{
                                          color: MUTED,
                                          fontSize: 10,
                                          fontWeight: "800",
                                          marginBottom: 2,
                                        }}
                                      >
                                        MIN RAM
                                      </Text>
                                      <Text
                                        style={{ color: TEXT, fontSize: 11 }}
                                      >
                                        {tool.minRam}
                                      </Text>
                                    </View>
                                  </View>
                                )}
                                {tool.notes && (
                                  <View
                                    style={{
                                      flexDirection: "row",
                                      gap: 8,
                                      alignItems: "flex-start",
                                    }}
                                  >
                                    <Text style={{ fontSize: 13 }}>📝</Text>
                                    <View style={{ flex: 1 }}>
                                      <Text
                                        style={{
                                          color: MUTED,
                                          fontSize: 10,
                                          fontWeight: "800",
                                          marginBottom: 2,
                                        }}
                                      >
                                        NOTES
                                      </Text>
                                      <Text
                                        style={{
                                          color: MUTED,
                                          fontSize: 11,
                                          lineHeight: 16,
                                        }}
                                      >
                                        {tool.notes}
                                      </Text>
                                    </View>
                                  </View>
                                )}
                              </View>
                            )}

                            {/* Script block */}
                            <View
                              style={{
                                backgroundColor: SCRIPT_BG,
                                borderRadius: 10,
                                borderWidth: 1,
                                borderColor: cat.color + "50",
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
                                {tool.script}
                              </Text>
                            </View>
                            <TouchableOpacity
                              onPress={() =>
                                handleCopy(tool.script, copyId, tool.name)
                              }
                              style={{
                                marginTop: 10,
                                backgroundColor:
                                  copiedId === copyId ? "#10B981" : cat.color,
                                borderRadius: 10,
                                paddingVertical: 13,
                                flexDirection: "row",
                                alignItems: "center",
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
                                  : "Copy Install Script"}
                              </Text>
                            </TouchableOpacity>
                          </View>
                        )}

                        {idx < cat.tools.length - 1 && (
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

        {/* Footer note */}
        <View
          style={{
            backgroundColor: CYAN + "12",
            borderRadius: 12,
            borderWidth: 1,
            borderColor: CYAN + "35",
            padding: 14,
            marginTop: 6,
            flexDirection: "row",
            gap: 10,
            alignItems: "flex-start",
          }}
        >
          <Text style={{ fontSize: 18 }}>💡</Text>
          <Text style={{ color: CYAN, fontSize: 12, flex: 1, lineHeight: 18 }}>
            Copy any script and paste it into your VPS terminal as root. Scripts
            auto-install dependencies.
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}
