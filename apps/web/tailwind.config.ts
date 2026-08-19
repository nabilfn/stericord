import type { Config } from "tailwindcss";

export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: "#0B1F3A",
          light: "#132C52",
        },
        teal: {
          DEFAULT: "#0F766E",
          light: "#14B8A6",
        },
        "sc-blue": {
          light: "#E6F1FB",
          DEFAULT: "#3B82F6",
        },
        pass: "#16A34A",
        warning: "#D97706",
        fail: "#DC2626",
      },
    },
  },
  plugins: [],
} satisfies Config;
