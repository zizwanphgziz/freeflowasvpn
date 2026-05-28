import { Tabs } from "expo-router";
import { View, Text } from "react-native";
import { useTheme } from "@/utils/ThemeContext";

function TabIcon({ emoji, focused, activeColor }) {
  return (
    <View
      style={{
        alignItems: "center",
        justifyContent: "center",
        width: 32,
        height: 32,
        borderRadius: 8,
        backgroundColor: focused ? activeColor + "20" : "transparent",
      }}
    >
      <Text style={{ fontSize: 18 }}>{emoji}</Text>
    </View>
  );
}

export default function TabLayout() {
  const { theme } = useTheme();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: theme.CARD,
          borderTopWidth: 1,
          borderTopColor: theme.BORDER,
          paddingTop: 6,
          paddingBottom: 4,
          elevation: 0,
        },
        tabBarActiveTintColor: theme.CYAN,
        tabBarInactiveTintColor: theme.MUTED,
        tabBarLabelStyle: {
          fontSize: 10,
          fontWeight: "700",
          letterSpacing: 0.3,
          marginTop: 2,
        },
      }}
    >
      <Tabs.Screen
        name="rebuild"
        options={{
          title: "Rebuild",
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="🖥️" focused={focused} activeColor={theme.CYAN} />
          ),
        }}
      />
      <Tabs.Screen
        name="vpn"
        options={{
          title: "VPN",
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="🔒" focused={focused} activeColor={theme.CYAN} />
          ),
        }}
      />
      <Tabs.Screen
        name="vps"
        options={{
          title: "My VPS",
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="🌐" focused={focused} activeColor={theme.CYAN} />
          ),
        }}
      />
      <Tabs.Screen
        name="history"
        options={{
          title: "History",
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="📜" focused={focused} activeColor={theme.CYAN} />
          ),
        }}
      />
      <Tabs.Screen
        name="quick"
        options={{
          title: "Quick",
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="⚡" focused={focused} activeColor={theme.CYAN} />
          ),
        }}
      />
    </Tabs>
  );
}
