const BASE =
  "bash <(curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh)";

export const osData = [
  {
    id: "debian",
    name: "Debian",
    icon: "🌀",
    color: "#A80030",
    category: "linux",
    description: "Rock-solid stability for servers.",
    versions: [
      {
        version: "13",
        codename: "Trixie",
        script: `${BASE} debian 13 && reboot`,
      },
      {
        version: "12",
        codename: "Bookworm",
        script: `${BASE} debian 12 && reboot`,
      },
      {
        version: "11",
        codename: "Bullseye",
        script: `${BASE} debian 11 && reboot`,
      },
      {
        version: "10",
        codename: "Buster",
        script: `${BASE} debian 10 && reboot`,
      },
      {
        version: "9",
        codename: "Stretch",
        script: `${BASE} debian 9 && reboot`,
      },
    ],
  },
  {
    id: "ubuntu",
    name: "Ubuntu",
    icon: "🟠",
    color: "#E95420",
    category: "linux",
    description: "Most popular Linux for cloud & VPS.",
    versions: [
      {
        version: "26.04",
        codename: "Resolute Raccoon",
        script: `${BASE} ubuntu 26.04 && reboot`,
      },
      {
        version: "24.04",
        codename: "Noble Numbat",
        script: `${BASE} ubuntu 24.04 && reboot`,
      },
      {
        version: "22.04",
        codename: "Jammy Jellyfish",
        script: `${BASE} ubuntu 22.04 && reboot`,
      },
      {
        version: "20.04",
        codename: "Focal Fossa",
        script: `${BASE} ubuntu 20.04 && reboot`,
      },
      {
        version: "18.04",
        codename: "Bionic Beaver",
        script: `${BASE} ubuntu 18.04 && reboot`,
      },
    ],
  },
  {
    id: "centos",
    name: "CentOS",
    icon: "🟣",
    color: "#932279",
    category: "linux",
    description: "Community-driven enterprise Linux.",
    versions: [
      {
        version: "9 Stream",
        codename: "Stream",
        script: `${BASE} centos 9 && reboot`,
      },
      {
        version: "8 Stream",
        codename: "Stream",
        script: `${BASE} centos 8 && reboot`,
      },
      { version: "7", codename: "Final", script: `${BASE} centos 7 && reboot` },
    ],
  },
  {
    id: "almalinux",
    name: "AlmaLinux",
    icon: "🔵",
    color: "#0F4266",
    category: "linux",
    description: "1:1 binary compatible with RHEL.",
    versions: [
      {
        version: "10",
        codename: "Purple Manul",
        script: `${BASE} alma 10 && reboot`,
      },
      {
        version: "9",
        codename: "Emerald Puma",
        script: `${BASE} alma 9 && reboot`,
      },
      {
        version: "8",
        codename: "Cerulean Leopard",
        script: `${BASE} alma 8 && reboot`,
      },
    ],
  },
  {
    id: "rocky",
    name: "Rocky Linux",
    icon: "🟢",
    color: "#10B981",
    category: "linux",
    description: "Bug-for-bug RHEL compatible.",
    versions: [
      {
        version: "10",
        codename: "Obsidian Owl",
        script: `${BASE} rocky 10 && reboot`,
      },
      {
        version: "9",
        codename: "Blue Onyx",
        script: `${BASE} rocky 9 && reboot`,
      },
      {
        version: "8",
        codename: "Green Obsidian",
        script: `${BASE} rocky 8 && reboot`,
      },
    ],
  },
  {
    id: "fedora",
    name: "Fedora",
    icon: "🎩",
    color: "#3C6EB4",
    category: "linux",
    description: "Cutting-edge Linux from Red Hat.",
    versions: [
      { version: "44", script: `${BASE} fedora 44 && reboot` },
      { version: "43", script: `${BASE} fedora 43 && reboot` },
      { version: "42", script: `${BASE} fedora 42 && reboot` },
      { version: "41", script: `${BASE} fedora 41 && reboot` },
      { version: "40", script: `${BASE} fedora 40 && reboot` },
    ],
  },
  {
    id: "arch",
    name: "Arch Linux",
    icon: "🏔️",
    color: "#1793D1",
    category: "linux",
    description: "Lightweight, rolling-release for power users.",
    versions: [
      {
        version: "Latest",
        codename: "Rolling",
        script: `${BASE} arch && reboot`,
      },
    ],
  },
  {
    id: "opensuse",
    name: "openSUSE",
    icon: "🦎",
    color: "#73BA25",
    category: "linux",
    description: "Stable with YaST management tools.",
    versions: [
      {
        version: "Tumbleweed",
        codename: "Rolling",
        script: `${BASE} opensuse tumbleweed && reboot`,
      },
      {
        version: "15.6",
        codename: "Leap",
        script: `${BASE} opensuse 15.6 && reboot`,
      },
    ],
  },
  {
    id: "alpine",
    name: "Alpine Linux",
    icon: "⛰️",
    color: "#0D597F",
    category: "linux",
    description: "Security-oriented, lightweight distro.",
    versions: [
      { version: "3.23", script: `${BASE} alpine 3.23 && reboot` },
      { version: "3.22", script: `${BASE} alpine 3.22 && reboot` },
      { version: "3.21", script: `${BASE} alpine 3.21 && reboot` },
      { version: "3.20", script: `${BASE} alpine 3.20 && reboot` },
    ],
  },
  {
    id: "oracle",
    name: "Oracle Linux",
    icon: "🔴",
    color: "#C74634",
    category: "linux",
    description: "Enterprise Linux with Ksplice support.",
    versions: [
      { version: "10", script: `${BASE} oracle 10 && reboot` },
      { version: "9", script: `${BASE} oracle 9 && reboot` },
      { version: "8", script: `${BASE} oracle 8 && reboot` },
    ],
  },
  {
    id: "gentoo",
    name: "Gentoo",
    icon: "🐧",
    color: "#54487A",
    category: "linux",
    description: "Source-based, ultimate customization.",
    versions: [
      {
        version: "Latest",
        codename: "Rolling",
        script: `${BASE} gentoo && reboot`,
      },
    ],
  },
  {
    id: "nixos",
    name: "NixOS",
    icon: "❄️",
    color: "#5277C3",
    category: "linux",
    description: "Declarative, reproducible Linux.",
    versions: [
      {
        version: "24.11",
        codename: "Vicuna",
        script: `${BASE} nixos 24.11 && reboot`,
      },
      {
        version: "24.05",
        codename: "Uakari",
        script: `${BASE} nixos 24.05 && reboot`,
      },
    ],
  },
  {
    id: "kali",
    name: "Kali Linux",
    icon: "🐉",
    color: "#557C94",
    category: "linux",
    description: "Penetration testing distribution.",
    versions: [
      {
        version: "Latest",
        codename: "Rolling",
        script: `${BASE} kali && reboot`,
      },
    ],
  },
  {
    id: "anolis",
    name: "Anolis OS",
    icon: "🐜",
    color: "#1E90FF",
    category: "linux",
    description: "Cloud-native by Alibaba Cloud.",
    versions: [
      {
        version: "23",
        codename: "Innovation",
        script: `${BASE} anolis 23 && reboot`,
      },
      {
        version: "8",
        codename: "Stable",
        script: `${BASE} anolis 8 && reboot`,
      },
      {
        version: "7",
        codename: "Classic",
        script: `${BASE} anolis 7 && reboot`,
      },
    ],
  },
  {
    id: "opencloudos",
    name: "OpenCloudOS",
    icon: "☁️",
    color: "#FF6600",
    category: "linux",
    description: "Community-driven cloud OS by Tencent.",
    versions: [
      { version: "9", script: `${BASE} opencloudos 9 && reboot` },
      { version: "8", script: `${BASE} opencloudos 8 && reboot` },
    ],
  },
  // Windows
  {
    id: "windows-server",
    name: "Windows Server",
    icon: "🪟",
    color: "#0078D4",
    category: "windows",
    description: "Microsoft Windows Server editions.",
    versions: [
      { version: "2025", script: `${BASE} windows 2025 && reboot` },
      { version: "2022", script: `${BASE} windows 2022 && reboot` },
      { version: "2019", script: `${BASE} windows 2019 && reboot` },
      { version: "2016", script: `${BASE} windows 2016 && reboot` },
    ],
  },
  {
    id: "windows",
    name: "Windows",
    icon: "💠",
    color: "#00BCF2",
    category: "windows",
    description: "Microsoft Windows desktop editions.",
    versions: [
      { version: "11", script: `${BASE} windows 11 && reboot` },
      { version: "10", script: `${BASE} windows 10 && reboot` },
    ],
  },
];

export const quickRef = [
  { label: "Debian 12", script: `${BASE} debian 12 && reboot` },
  { label: "Ubuntu 24.04", script: `${BASE} ubuntu 24.04 && reboot` },
  { label: "CentOS 9 Stream", script: `${BASE} centos 9 && reboot` },
  { label: "AlmaLinux 9", script: `${BASE} alma 9 && reboot` },
  { label: "Rocky Linux 9", script: `${BASE} rocky 9 && reboot` },
  { label: "Kali Linux", script: `${BASE} kali && reboot` },
  { label: "Alpine 3.23", script: `${BASE} alpine 3.23 && reboot` },
  { label: "Windows Server 2022", script: `${BASE} windows 2022 && reboot` },
];
