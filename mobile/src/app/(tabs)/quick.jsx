import { useState, useCallback, useEffect } from "react";
import { View, Text, ScrollView, TouchableOpacity } from "react-native";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { quickRef } from "../../data/osData";
import { useTheme } from "@/utils/ThemeContext";

const BG = "#0B0F1A";
const CARD = "#111827";
const BORDER = "#1E2D45";
const CYAN = "#00C8C8";
const TEAL = "#00C896";
const BLUE = "#0080B4";
const TEXT = "#E8F0F8";
const MUTED = "#5A7090";
const LOGO =
  "https://dtvoeevhaseb5.cloudfront.net/user-uploads/f8f5b2b0-a11f-4713-8f86-06409841e8a9.jpg";

const BASE =
  "bash <(curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh)";

const tips = [
  {
    icon: "🔑",
    title: "Custom Root Password",
    body: "Add --password YOUR_PASS to any script to set a custom root password after rebuild.",
  },
  {
    icon: "🌐",
    title: "KVM/Xen Only",
    body: "Scripts work on KVM/Xen VPS. OpenVZ & LXC containers are NOT supported.",
  },
  {
    icon: "⏱️",
    title: "Rebuild Time",
    body: "Typically 5–15 minutes depending on VPS specs and network speed.",
  },
  {
    icon: "🔒",
    title: "Windows License",
    body: "Windows scripts are free & open source — but you need a valid license key to activate.",
  },
  {
    icon: "💾",
    title: "Backup First!",
    body: "Scripts completely wipe all data. Always back up your files before running.",
  },
  {
    icon: "📡",
    title: "Supported Providers",
    body: "Compatible with Vultr, DigitalOcean, Linode, Hetzner, OVH, Contabo, and more.",
  },
];

const HISTORY_KEY = "@freeflow_history";
const FAVORITES_KEY = "@freeflow_favorites";

const VPS_PROVIDERS = [
  { name: "Vultr", kvm: true },
  { name: "Hetzner", kvm: true },
  { name: "DigitalOcean", kvm: true },
  { name: "Linode", kvm: true },
  { name: "Contabo", kvm: true },
  { name: "OVH", kvm: true },
  { name: "Netcup", kvm: true },
  { name: "Scaleway", kvm: true },
  { name: "AWS Lightsail", kvm: true },
  { name: "Google Cloud", kvm: true },
  { name: "Azure", kvm: true },
  { name: "RackNerd", kvm: true },
  { name: "BuyVM", kvm: true },
  { name: "Hostinger", kvm: false, note: "OpenVZ" },
  { name: "Virmach (some)", kvm: false, note: "Mixed" },
];

export default function QuickScreen() {
  const insets = useSafeAreaInsets();
  const { theme, toggleTheme, isDark } = useTheme();
  const {
    BG,
    CARD,
    BORDER,
    CYAN,
    TEAL,
    BLUE,
    TEXT,
    MUTED,
    STATUS_BAR,
    SCRIPT_BG,
    SCRIPT_TEXT,
  } = theme;
  const [copiedId, setCopiedId] = useState(null);
  const [copiedAll, setCopiedAll] = useState(false);
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

  const handleCopyBase = useCallback(async () => {
    await Clipboard.setStringAsync(BASE);
    await saveToHistory(BASE, "Base Script URL");
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedAll(true);
    setTimeout(() => setCopiedAll(false), 2200);
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
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: 6,
          }}
        >
          <Image
            source={{ uri: LOGO }}
            style={{ width: 160, height: 46 }}
            contentFit="contain"
          />
          {/* Theme toggle */}
          <TouchableOpacity
            onPress={() => {
              toggleTheme();
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
            }}
            style={{
              backgroundColor: CARD,
              borderRadius: 20,
              borderWidth: 1,
              borderColor: BORDER,
              paddingHorizontal: 14,
              paddingVertical: 8,
              flexDirection: "row",
              alignItems: "center",
              gap: 6,
            }}
          >
            <Text style={{ fontSize: 16 }}>{isDark ? "☀️" : "🌙"}</Text>
            <Text
              style={{
                color: TEXT,
                fontSize: 12,
                fontWeight: "700",
              }}
            >
              {isDark ? "Light" : "Dark"}
            </Text>
          </TouchableOpacity>
        </View>
        <Text style={{ color: MUTED, fontSize: 13 }}>
          Quick Reference & Tips
        </Text>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{
          paddingHorizontal: 16,
          paddingBottom: insets.bottom + 90,
        }}
        showsVerticalScrollIndicator={false}
      >
        {/* Base script card */}
        <View
          style={{
            backgroundColor: CARD,
            borderRadius: 14,
            borderWidth: 1,
            borderColor: CYAN + "50",
            padding: 16,
            marginBottom: 20,
          }}
        >
          <View
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: 10,
              marginBottom: 10,
            }}
          >
            <View
              style={{
                backgroundColor: CYAN + "22",
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 5,
              }}
            >
              <Text
                style={{
                  color: CYAN,
                  fontWeight: "800",
                  fontSize: 12,
                  letterSpacing: 0.5,
                }}
              >
                BASE SCRIPT
              </Text>
            </View>
          </View>
          <Text
            style={{
              color: MUTED,
              fontSize: 12,
              marginBottom: 10,
              lineHeight: 18,
            }}
          >
            All commands use this trusted open-source reinstall script from
            bin456789:
          </Text>
          <View
            style={{
              backgroundColor: SCRIPT_BG,
              borderRadius: 10,
              borderWidth: 1,
              borderColor: TEAL + "40",
              padding: 12,
              marginBottom: 12,
            }}
          >
            <Text
              style={{
                color: SCRIPT_TEXT,
                fontFamily: "monospace",
                fontSize: 10,
                lineHeight: 17,
              }}
            >
              {BASE}
            </Text>
          </View>
          <TouchableOpacity
            onPress={handleCopyBase}
            style={{
              backgroundColor: copiedAll ? "#10B981" : CYAN,
              borderRadius: 10,
              paddingVertical: 12,
              flexDirection: "row",
              alignItems: "center",
              justifyContent: "center",
              gap: 8,
            }}
          >
            <Text style={{ fontSize: 15 }}>{copiedAll ? "✅" : "📋"}</Text>
            <Text style={{ color: "#000F1A", fontWeight: "800", fontSize: 14 }}>
              {copiedAll ? "Copied!" : "Copy Base URL"}
            </Text>
          </TouchableOpacity>
        </View>

        {/* Compatibility Checker */}
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
              fontWeight: "700",
              fontSize: 15,
              marginBottom: 10,
            }}
          >
            🔍 Provider Compatibility
          </Text>
          <Text
            style={{
              color: MUTED,
              fontSize: 12,
              marginBottom: 14,
              lineHeight: 18,
            }}
          >
            Scripts require KVM or Xen virtualization. OpenVZ/LXC containers are
            NOT supported.
          </Text>
          <View style={{ gap: 6 }}>
            {VPS_PROVIDERS.map((provider, idx) => (
              <View
                key={idx}
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  justifyContent: "space-between",
                  backgroundColor: BG,
                  borderRadius: 8,
                  padding: 10,
                }}
              >
                <Text style={{ color: TEXT, fontSize: 13, fontWeight: "600" }}>
                  {provider.name}
                </Text>
                <View
                  style={{ flexDirection: "row", alignItems: "center", gap: 6 }}
                >
                  {provider.note && (
                    <Text style={{ color: MUTED, fontSize: 11 }}>
                      {provider.note}
                    </Text>
                  )}
                  <View
                    style={{
                      backgroundColor: provider.kvm ? "#10B98125" : "#EF444425",
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 3,
                    }}
                  >
                    <Text
                      style={{
                        color: provider.kvm ? "#10B981" : "#EF4444",
                        fontSize: 11,
                        fontWeight: "700",
                      }}
                    >
                      {provider.kvm ? "✅ KVM" : "❌ OpenVZ"}
                    </Text>
                  </View>
                </View>
              </View>
            ))}
          </View>
        </View>

        {/* Quick commands */}
        <Text
          style={{
            color: TEXT,
            fontWeight: "700",
            fontSize: 16,
            marginBottom: 12,
          }}
        >
          ⚡ Most Popular Commands
        </Text>
        {quickRef.map((item, idx) => {
          const copyId = `quick-${idx}`;
          const isCopied = copiedId === copyId;
          const isFav = isFavorited(item.script);
          return (
            <View
              key={idx}
              style={{
                backgroundColor: CARD,
                borderRadius: 12,
                borderWidth: 1,
                borderColor: BORDER,
                marginBottom: 8,
                overflow: "hidden",
              }}
            >
              {/* Label row */}
              <View
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  justifyContent: "space-between",
                  paddingHorizontal: 14,
                  paddingVertical: 10,
                  borderBottomWidth: 1,
                  borderBottomColor: BORDER,
                }}
              >
                <Text style={{ color: CYAN, fontWeight: "700", fontSize: 13 }}>
                  {item.label}
                </Text>
                <View
                  style={{ flexDirection: "row", alignItems: "center", gap: 8 }}
                >
                  <TouchableOpacity
                    onPress={() => toggleFavorite(item.script, item.label)}
                  >
                    <Text style={{ fontSize: 18 }}>{isFav ? "⭐" : "☆"}</Text>
                  </TouchableOpacity>
                  <View
                    style={{
                      backgroundColor: CYAN + "18",
                      borderRadius: 6,
                      paddingHorizontal: 8,
                      paddingVertical: 3,
                    }}
                  >
                    <Text
                      style={{ color: CYAN, fontSize: 10, fontWeight: "700" }}
                    >
                      POPULAR
                    </Text>
                  </View>
                </View>
              </View>
              {/* Script */}
              <View style={{ paddingHorizontal: 14, paddingTop: 10 }}>
                <Text
                  style={{
                    color: TEAL,
                    fontFamily: "monospace",
                    fontSize: 10,
                    lineHeight: 17,
                  }}
                  numberOfLines={2}
                >
                  {item.script}
                </Text>
              </View>
              {/* Copy button */}
              <TouchableOpacity
                onPress={() => handleCopy(item.script, copyId, item.label)}
                style={{
                  flexDirection: "row",
                  alignItems: "center",
                  gap: 6,
                  paddingHorizontal: 14,
                  paddingVertical: 10,
                  marginTop: 4,
                }}
              >
                <Text style={{ fontSize: 14 }}>{isCopied ? "✅" : "📋"}</Text>
                <Text
                  style={{
                    color: isCopied ? "#10B981" : BLUE,
                    fontWeight: "700",
                    fontSize: 13,
                  }}
                >
                  {isCopied ? "Copied to clipboard!" : "Copy command"}
                </Text>
              </TouchableOpacity>
            </View>
          );
        })}

        {/* Tips section */}
        <Text
          style={{
            color: TEXT,
            fontWeight: "700",
            fontSize: 16,
            marginTop: 10,
            marginBottom: 12,
          }}
        >
          💡 Tips & Notes
        </Text>
        {tips.map((tip, idx) => (
          <View
            key={idx}
            style={{
              backgroundColor: CARD,
              borderRadius: 12,
              borderWidth: 1,
              borderColor: BORDER,
              padding: 14,
              marginBottom: 8,
              flexDirection: "row",
              gap: 12,
              alignItems: "flex-start",
            }}
          >
            <View
              style={{
                width: 38,
                height: 38,
                borderRadius: 10,
                backgroundColor: CYAN + "18",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Text style={{ fontSize: 18 }}>{tip.icon}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text
                style={{
                  color: TEXT,
                  fontWeight: "700",
                  fontSize: 13,
                  marginBottom: 4,
                }}
              >
                {tip.title}
              </Text>
              <Text style={{ color: MUTED, fontSize: 12, lineHeight: 18 }}>
                {tip.body}
              </Text>
            </View>
          </View>
        ))}

        {/* Footer */}
        <View
          style={{
            backgroundColor: TEAL + "12",
            borderRadius: 12,
            borderWidth: 1,
            borderColor: TEAL + "35",
            padding: 14,
            marginTop: 6,
            flexDirection: "row",
            gap: 10,
            alignItems: "center",
          }}
        >
          <Text style={{ fontSize: 20 }}>🔗</Text>
          <View style={{ flex: 1 }}>
            <Text
              style={{
                color: TEAL,
                fontWeight: "700",
                fontSize: 13,
                marginBottom: 3,
              }}
            >
              Source: bin456789/reinstall
            </Text>
            <Text style={{ color: MUTED, fontSize: 11, lineHeight: 17 }}>
              All scripts sourced from a trusted open-source project. Audit the
              code on GitHub.
            </Text>
          </View>
        </View>
      </ScrollView>
    </View>
  );
}
