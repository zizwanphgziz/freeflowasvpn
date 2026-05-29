import { createContext, useContext, useState, useEffect } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";

const THEME_KEY = "@freeflow_theme";

export const darkTheme = {
  mode: "dark",
  BG: "#0B0F1A",
  BG2: "#060B14",
  CARD: "#111827",
  BORDER: "#1E2D45",
  CYAN: "#00C8C8",
  TEAL: "#00C896",
  BLUE: "#0080B4",
  TEXT: "#E8F0F8",
  MUTED: "#5A7090",
  WARN: "#F59E0B",
  GREEN: "#10B981",
  RED: "#EF4444",
  ORANGE: "#F59E0B",
  STATUS_BAR: "light",
  SCRIPT_BG: "#060B14",
  SCRIPT_TEXT: "#00C896",
};

export const lightTheme = {
  mode: "light",
  BG: "#F0F4F8",
  BG2: "#E2E8F0",
  CARD: "#FFFFFF",
  BORDER: "#CBD5E1",
  CYAN: "#007A8A",
  TEAL: "#006650",
  BLUE: "#005F8A",
  TEXT: "#0F172A",
  MUTED: "#64748B",
  WARN: "#D97706",
  GREEN: "#059669",
  RED: "#DC2626",
  ORANGE: "#D97706",
  STATUS_BAR: "dark",
  SCRIPT_BG: "#1E293B",
  SCRIPT_TEXT: "#4ADE80",
};

const ThemeContext = createContext({
  theme: darkTheme,
  toggleTheme: () => {},
  isDark: true,
});

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(darkTheme);

  useEffect(() => {
    AsyncStorage.getItem(THEME_KEY)
      .then((val) => {
        if (val === "light") setTheme(lightTheme);
      })
      .catch(() => {});
  }, []);

  const toggleTheme = async () => {
    const next = theme.mode === "dark" ? lightTheme : darkTheme;
    setTheme(next);
    await AsyncStorage.setItem(THEME_KEY, next.mode).catch(() => {});
  };

  return (
    <ThemeContext.Provider
      value={{ theme, toggleTheme, isDark: theme.mode === "dark" }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeContext);
}
