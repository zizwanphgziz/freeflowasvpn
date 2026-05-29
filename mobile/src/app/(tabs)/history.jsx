import { useState, useCallback, useEffect } from "react";
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
} from "react-native";
import { Image } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import { StatusBar } from "expo-status-bar";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useTheme } from "@/utils/ThemeContext";

const LOGO =
  "https://dtvoeevhaseb5.cloudfront.net/user-uploads/f8f5b2b0-a11f-4713-8f86-06409841e8a9.jpg";
const HISTORY_KEY = "@freeflow_history";
const FAVORITES_KEY = "@freeflow_favorites";

export default function HistoryScreen() {
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
    WARN,
    GREEN,
    STATUS_BAR,
    SCRIPT_BG,
    SCRIPT_TEXT,
  } = theme;

  const [history, setHistory] = useState([]);
  const [favorites, setFavorites] = useState([]);
  const [tab, setTab] = useState("favorites");
  const [copiedId, setCopiedId] = useState(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [historyData, favoritesData] = await Promise.all([
        AsyncStorage.getItem(HISTORY_KEY),
        AsyncStorage.getItem(FAVORITES_KEY),
      ]);
      if (historyData) setHistory(JSON.parse(historyData));
      if (favoritesData) setFavorites(JSON.parse(favoritesData));
    } catch (e) {
      console.error("Failed to load data", e);
    }
  };

  const handleCopy = useCallback(async (script, id) => {
    await Clipboard.setStringAsync(script);
    await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  }, []);

  const handleClearHistory = () => {
    Alert.alert(
      "Clear History",
      "Delete all command history? Favorites will not be affected.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Clear",
          style: "destructive",
          onPress: async () => {
            await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify([]));
            setHistory([]);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          },
        },
      ],
    );
  };

  const toggleFavorite = async (item) => {
    const isFav = favorites.some((f) => f.script === item.script);
    let updated;
    if (isFav) {
      updated = favorites.filter((f) => f.script !== item.script);
    } else {
      updated = [...favorites, { ...item, favoritedAt: Date.now() }];
    }
    await AsyncStorage.setItem(FAVORITES_KEY, JSON.stringify(updated));
    setFavorites(updated);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  };

  const isFavorited = (script) => favorites.some((f) => f.script === script);

  const formatTime = (ts) => {
    if (!ts) return "Unknown";
    const date = new Date(ts);
    const now = new Date();
    const diff = now - date;
    const mins = Math.floor(diff / 60000);
    const hrs = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    if (mins < 1) return "Just now";
    if (mins < 60) return `${mins}m ago`;
    if (hrs < 24) return `${hrs}h ago`;
    if (days < 7) return `${days}d ago`;
    return date.toLocaleDateString();
  };

  const filterItems = (items) => {
    if (!search.trim()) return items;
    const q = search.toLowerCase();
    return items.filter(
      (i) =>
        (i.label || "").toLowerCase().includes(q) ||
        (i.script || "").toLowerCase().includes(q),
    );
  };

  const displayFavorites = filterItems(favorites);
  const displayHistory = filterItems([...history].reverse());

  const renderItem = (item, idx) => {
    const copyId = `${tab}-${idx}`;
    const isCopied = copiedId === copyId;
    const isFav = isFavorited(item.script);
    return (
      <View
        key={`${tab}-${idx}-${item.script?.slice(0, 20)}`}
        style={{
          backgroundColor: CARD,
          borderRadius: 12,
          borderWidth: 1,
          borderColor: BORDER,
          padding: 14,
          marginBottom: 10,
        }}
      >
        <View
          style={{
            flexDirection: "row",
            alignItems: "flex-start",
            justifyContent: "space-between",
            marginBottom: 10,
          }}
        >
          <View style={{ flex: 1, marginRight: 8 }}>
            <Text
              style={{
                color: TEXT,
                fontWeight: "700",
                fontSize: 14,
                marginBottom: 4,
              }}
            >
              {item.label || "Unnamed Script"}
            </Text>
            <Text style={{ color: MUTED, fontSize: 11 }}>
              {formatTime(item.timestamp || item.copiedAt || item.favoritedAt)}
            </Text>
          </View>
          <TouchableOpacity onPress={() => toggleFavorite(item)}>
            <Text style={{ fontSize: 22 }}>{isFav ? "⭐" : "☆"}</Text>
          </TouchableOpacity>
        </View>

        <View
          style={{
            backgroundColor: SCRIPT_BG,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: TEAL + "35",
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
            numberOfLines={2}
          >
            {item.script}
          </Text>
        </View>

        <TouchableOpacity
          onPress={() => handleCopy(item.script, copyId)}
          style={{
            backgroundColor: isCopied ? GREEN + "25" : CYAN + "20",
            borderRadius: 8,
            paddingVertical: 10,
            borderWidth: 1,
            borderColor: isCopied ? GREEN : CYAN,
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
          }}
        >
          <Text style={{ fontSize: 14 }}>{isCopied ? "✅" : "📋"}</Text>
          <Text
            style={{
              color: isCopied ? GREEN : CYAN,
              fontWeight: "800",
              fontSize: 12,
            }}
          >
            {isCopied ? "Copied!" : "Copy Command"}
          </Text>
        </TouchableOpacity>
      </View>
    );
  };

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
          {tab === "history" && history.length > 0 && (
            <TouchableOpacity
              onPress={handleClearHistory}
              style={{
                backgroundColor: theme.RED + "20",
                borderRadius: 8,
                paddingHorizontal: 10,
                paddingVertical: 6,
                borderWidth: 1,
                borderColor: theme.RED,
              }}
            >
              <Text
                style={{ color: theme.RED, fontSize: 12, fontWeight: "700" }}
              >
                🗑️ Clear
              </Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Search bar */}
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            backgroundColor: CARD,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: BORDER,
            paddingHorizontal: 14,
            height: 42,
            marginBottom: 12,
          }}
        >
          <Text style={{ fontSize: 14, marginRight: 8 }}>🔍</Text>
          <TextInput
            placeholder="Search scripts or labels..."
            placeholderTextColor={MUTED}
            value={search}
            onChangeText={setSearch}
            style={{ flex: 1, color: TEXT, fontSize: 13 }}
          />
          {search.length > 0 && (
            <TouchableOpacity onPress={() => setSearch("")}>
              <Text style={{ color: MUTED, fontSize: 20 }}>×</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Tabs */}
        <View style={{ flexDirection: "row", gap: 10 }}>
          {[
            {
              key: "favorites",
              label: "⭐ Favorites",
              count: favorites.length,
            },
            { key: "history", label: "📜 History", count: history.length },
          ].map(({ key, label, count }) => (
            <TouchableOpacity
              key={key}
              onPress={() => setTab(key)}
              style={{
                flex: 1,
                paddingVertical: 10,
                borderRadius: 10,
                backgroundColor: tab === key ? CYAN : CARD,
                borderWidth: 1,
                borderColor: tab === key ? CYAN : BORDER,
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "center",
                gap: 6,
              }}
            >
              <Text
                style={{
                  color: tab === key ? "#000F1A" : TEXT,
                  fontWeight: "700",
                  fontSize: 12,
                }}
              >
                {label}
              </Text>
              <View
                style={{
                  backgroundColor: tab === key ? "#000F1A30" : CYAN + "25",
                  borderRadius: 5,
                  paddingHorizontal: 6,
                  paddingVertical: 2,
                }}
              >
                <Text
                  style={{
                    color: tab === key ? "#000F1A" : CYAN,
                    fontSize: 10,
                    fontWeight: "800",
                  }}
                >
                  {count}
                </Text>
              </View>
            </TouchableOpacity>
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
        keyboardShouldPersistTaps="handled"
      >
        {/* Search result count */}
        {search.trim().length > 0 && (
          <Text style={{ color: MUTED, fontSize: 12, marginBottom: 10 }}>
            {tab === "favorites"
              ? displayFavorites.length
              : displayHistory.length}{" "}
            result
            {(tab === "favorites"
              ? displayFavorites.length
              : displayHistory.length) !== 1
              ? "s"
              : ""}{" "}
            for "{search}"
          </Text>
        )}

        {tab === "favorites" && displayFavorites.length === 0 && (
          <View style={{ alignItems: "center", paddingTop: 60 }}>
            <Text style={{ fontSize: 48, marginBottom: 12 }}>⭐</Text>
            <Text
              style={{
                color: TEXT,
                fontSize: 16,
                fontWeight: "700",
                marginBottom: 6,
              }}
            >
              {search ? "No matches found" : "No favorites yet"}
            </Text>
            <Text
              style={{
                color: MUTED,
                fontSize: 13,
                textAlign: "center",
                paddingHorizontal: 40,
              }}
            >
              {search
                ? "Try a different search term"
                : "Tap the star icon on any script to save it here"}
            </Text>
          </View>
        )}

        {tab === "history" && displayHistory.length === 0 && (
          <View style={{ alignItems: "center", paddingTop: 60 }}>
            <Text style={{ fontSize: 48, marginBottom: 12 }}>📜</Text>
            <Text
              style={{
                color: TEXT,
                fontSize: 16,
                fontWeight: "700",
                marginBottom: 6,
              }}
            >
              {search ? "No matches found" : "No history yet"}
            </Text>
            <Text
              style={{
                color: MUTED,
                fontSize: 13,
                textAlign: "center",
                paddingHorizontal: 40,
              }}
            >
              {search
                ? "Try a different search term"
                : "Copy any command and it will appear here"}
            </Text>
          </View>
        )}

        {tab === "favorites" && displayFavorites.map(renderItem)}
        {tab === "history" && displayHistory.map(renderItem)}

        {((tab === "favorites" && displayFavorites.length > 0) ||
          (tab === "history" && displayHistory.length > 0)) && (
          <View
            style={{
              backgroundColor: WARN + "15",
              borderRadius: 12,
              borderWidth: 1,
              borderColor: WARN + "40",
              padding: 14,
              marginTop: 6,
              flexDirection: "row",
              gap: 10,
              alignItems: "flex-start",
            }}
          >
            <Text style={{ fontSize: 16 }}>💡</Text>
            <Text
              style={{ color: WARN, fontSize: 12, flex: 1, lineHeight: 18 }}
            >
              {tab === "favorites"
                ? "Starred scripts are saved permanently across app restarts."
                : "History is auto-saved when you copy commands. Favorites won't be cleared."}
            </Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}
