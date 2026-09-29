<!-- 
==============================================================================
Author: Kamil BENMADI
Email: kamil.benmadi@sigma-clermont.fr
GitHub: https://github.com/Uncrowned0x0
==============================================================================
-->

# Kairos WS Light 🤖

Minimal workspace to simulate the **RB-KAIROS+** (omnidirectional base + UR5e robotic arm + **Tesollo DG-5F-R** gripper) via Docker, under **ROS 2 Jazzy** and **Gazebo Harmonic**.

---

## Table of Contents

1. [Overview](#overview)
2. [Convenience Script kairos.sh](#convenience-script-kairossh)
3. [Workspace Architecture](#workspace-architecture)
4. [Prerequisites](#prerequisites)
5. [Installation & First Run](#installation--first-run)
6. [Launching Simulation](#launching-simulation)
7. [Keyboard Teleoperation](#keyboard-teleoperation)
8. [Nav2 Autonomous Navigation](#nav2-autonomous-navigation)
9. [Tesollo DG-5F-R Gripper Control](#tesollo-dg-5f-r-gripper-control)
10. [Clean Shutdown](#clean-shutdown)
11. [Troubleshooting](#troubleshooting)
12. [Package Architecture](#package-architecture)

---

## Overview

This workspace contains **only the essential packages** required for:

| Feature | Package(s) |
|---|---|
| Kairos+ URDF Description | `rbkairos_description` |
| Gazebo Harmonic Simulation | `robotnik_gazebo_ignition` |
| Robotnik Base & Sensor Descriptions | `robotnik_description`, `robotnik_sensors` |
| Tesollo DG-5F-R Gripper | `dg_description`, `dg5f_gz`, `tesollo_tactile_mock` |
| Autonomous Navigation | `nav2_*` (installed via apt inside container) |
| Interactive Teleoperation | `kairos_teleop_keyboard.py` (arrow keys, crabbing, speed scaling, deadman safety) |

> **Note:** RL packages (`kairos_rl`, `rl_level0`), unused arms, and extra grippers have been excluded to keep this workspace lightweight and focused. If you are looking for the Deep Reinforcement Learning pipeline (Stable-Baselines3 PPO, Curriculum Learning), please check out the dedicated repository: **[RB-Kairos_ws_for_RL](https://github.com/Uncrowned0x0/RB-Kairos_ws_for_RL)**.

---

## Convenience Script `kairos.sh`

A dedicated bash script provides unified management commands. From `kairos_ws_light/`:

```bash
# Container Lifecycle & Build
./kairos.sh build                     # Build Docker image (with NVIDIA GPU acceleration)
./kairos.sh start                     # Start container in background
./kairos.sh shell                     # Open interactive bash shell in container
./kairos.sh colcon_build              # Compile ROS 2 packages inside container

# Modular Multi-Terminal Simulation Workflow (Recommended)
./kairos.sh world [world]             # Terminal 1: Launch Gazebo world alone (default: labo)
./kairos.sh robot [gripper] [rviz]    # Terminal 2: Spawn RB-KAIROS robot + RViz2
                                      #   gripper: schunk_egk50 (default) | tesollo_dg5f
                                      #   rviz: true (default) | false
./kairos.sh rviz                      # Terminal 2/4: Launch standalone RViz2
./kairos.sh nav2                      # Terminal 3: Launch Nav2 autonomous navigation
./kairos.sh teleop [direct|xterm]     # Terminal 3: Launch keyboard teleoperation

# Combined Shortcut (Single Terminal)
./kairos.sh sim [world] [gripper]     # Launch complete simulation (Gazebo + Robot + Nav2)

# Utilities
./kairos.sh gripper [right|left|both] # Launch Tesollo DG-5F-R controller
./kairos.sh clean                     # Clean shared memory & residual processes
./kairos.sh status                    # Show container and GPU status
./kairos.sh logs                      # Show real-time container logs
./kairos.sh stop                      # Stop container
./kairos.sh help                      # Display complete help & workflow
```

---

## Workspace Architecture

```
kairos_ws_light/
├── Dockerfile                   ← ROS 2 Jazzy + Gazebo Harmonic + Nav2 Docker image
├── docker-compose.yaml          ← Docker Compose with NVIDIA GPU acceleration by default
├── docker-compose.gpu.yaml      ← Dedicated NVIDIA GPU override configuration
├── kairos.sh                    ← ✨ Convenience script (world/robot/rviz/nav2/teleop/...)
├── instructions_sim.md            ← Step-by-step instructions (Terminal/Docker details)
├── docker/
│   ├── kairos-entrypoint.sh     ← Container entrypoint initialization script
│   └── requirements/
│       ├── builder/packages.txt ← System build tools
│       └── base/packages.txt    ← ROS 2 + Gazebo + Nav2 system packages
└── src/
    ├── kairos_bringup/               ← ✨ Primary ROS 2 bringup package
    │   └── launch/
    │       ├── kairos_world.launch.py         ← Terminal 1: Gazebo world alone (labo)
    │       ├── kairos_robot.launch.py         ← Terminal 2: RB-KAIROS spawn + controllers
    │       ├── kairos_rviz.launch.py          ← Terminal 2/4: Standalone RViz2
    │       ├── kairos_nav2.launch.py          ← Terminal 3: Nav2 standalone launcher
    │       ├── kairos_teleop.launch.py        ← Terminal 3: Teleoperation launcher
    │       └── kairos_sim_complete.launch.py  ← Full simulation all-in-one shortcut
    ├── rbkairos_description/          ← URDF, Nav2 configurations, twist_relay script
    ├── delto_m_ros2/
    │   ├── dg_description/            ← Tesollo DG-5F-R URDF & 3D meshes
    │   ├── dg5f_gz/                   ← Tesollo Gazebo Harmonic plugin
    │   └── dg_msgs/                   ← Tesollo custom ROS 2 messages
    ├── tesollo_tactile_mock/          ← Tactile sensor simulation mock
    ├── xela_description/              ← Xela sensor URDF
    ├── schunk_egk50_description/      ← Optional Schunk gripper description
    ├── Universal_Robots_ROS2_Description/ ← UR5e arm URDF
    └── robotnik/
        ├── robotnik_simulation/       ← Gazebo spawn world, robot, bringup
        ├── robotnik_description/      ← Official Robotnik robot definitions
        ├── robotnik_common/           ← Python launch utilities
        ├── robotnik_sensors/          ← Sensors (LiDAR, cameras)
        └── robotnik_interfaces/       ← Robotnik interfaces and services
```

---

## Prerequisites

### Required Software

| Software | Minimum Version | Check Command |
|---|---|---|
| Ubuntu | 22.04 or 24.04 | `lsb_release -a` |
| Docker Engine | ≥ 24.0 | `docker --version` |
| Docker Compose | ≥ 2.20 (v2 plugin) | `docker compose version` |

### X11 Display Authorization

To allow Gazebo and RViz windows to render on the host screen:

```bash
xhost +local:docker
```

Add this line to `~/.bashrc` to make it permanent across terminal sessions:
```bash
echo "xhost +local:docker" >> ~/.bashrc
```

### [Optional] NVIDIA GPU Hardware Acceleration

If your workstation is equipped with an NVIDIA GPU:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## Installation & First Run

### Step 1 — Build the Docker Image

From the workspace root directory:

```bash
cd /home/YourMachine/kairos_ws_light
./kairos.sh build
```

### Step 2 — Start the Container

```bash
./kairos.sh start
./kairos.sh status
```

### Step 3 — Compile the ROS 2 Workspace

```bash
./kairos.sh colcon_build
```

---

## Launching Simulation

### Modular Multi-Terminal Workflow (Recommended)

To achieve maximum modularity, stability, and clean debugging, run the simulation across separate terminals:

```bash
# Terminal 1 — Start Gazebo Simulation World (default: labo)
./kairos.sh world labo

# Terminal 2 — Spawn RB-KAIROS Robot, Controllers & RViz2
# Supported grippers: schunk_egk50 (default) | tesollo_dg5f
./kairos.sh robot schunk_egk50

# (Optional: launch RViz2 separately if passing rviz:=false to robot command)
./kairos.sh rviz

# Terminal 3 — Navigation (Nav2) OR Keyboard Teleoperation
./kairos.sh nav2      # Launch Nav2 autonomous navigation
# Or:
./kairos.sh teleop    # Interactive keyboard teleoperation
```

> **Note:** For the raw underlying `docker exec` or `ros2 launch` commands (useful for pipelines or deeper understanding), please refer to the `instructions_sim.md` file.

### All-in-One Simulation (Shortcut)

Launch Gazebo Harmonic + RB-KAIROS+ + UR5e + Gripper + Nav2 in a single command:

```bash
./kairos.sh sim labo schunk_egk50
```

---

## Keyboard Teleoperation

In a separate terminal on the host:

```bash
cd /home/YourMachine/kairos_ws_light
./kairos.sh teleop
```

Or open in an external xterm window:

```bash
./kairos.sh teleop xterm
```

### Controls (Matching Real Robot Operation)

| Key | Action | Description |
|---|---|---|
| **Up Arrow** / `Z` / `W` / `I` | **Forward** | Positive longitudinal drive ($+v_x$) |
| **Down Arrow** / `S` / `K` | **Backward** | Negative longitudinal drive ($-v_x$) |
| **Left Arrow** / `Q` / `A` / `J` | **Turn Left** | Counter-clockwise yaw rotation ($+\omega_z$) |
| **Right Arrow** / `D` / `L` | **Turn Right** | Clockwise yaw rotation ($-\omega_z$) |
| **Shift + Left/Right** or `U` / `O` | **Mecanum Strafe** | Pure omnidirectional lateral drive ($+v_y$ / $-v_y$) |
| **`+`** or **`P`** | **Increase Speed** | $+0.02\text{ m/s}$ (Ceiling: $0.15\text{ m/s}$) |
| **`-`** or **`M`** | **Decrease Speed** | $-0.02\text{ m/s}$ (Floor: $0.03\text{ m/s}$) |
| **Space** or `X` / `C` | **Emergency Stop** | Immediate $0\text{ m/s}$ halt |
| **Ctrl+C** or **ESC** | **Quit** | Safe shutdown with zero velocity published |

> 🛡️ **Deadman Switch Safety:** If no key is received within $0.60\text{ s}$, velocity drops to zero.
> 💡 **Multi-Topic Output:** Publishes `TwistStamped` on `robotnik_base_control/reference` (`BEST_EFFORT` QoS, `robot_base_footprint`), `Twist` on `robotnik_base_control/reference_unstamped`, and `Twist` on `cmd_vel`.

---

## Nav2 Autonomous Navigation

Nav2 launches automatically inside `kairos_sim_complete.launch.py`.
To start Nav2 independently (Gazebo already running):

```bash
./kairos.sh nav2
```

### Sending Navigation Goals

1. **In RViz**: Select the **"2D Goal Pose"** button in the top toolbar, then click and drag on the map.
2. **Via CLI**: Please refer to `instructions_sim.md` for the exact `ros2 action send_goal` commands.

---

## Tesollo DG-5F-R Gripper Control

The Tesollo DG-5F-R features **20 joints** (4 per finger × 5 fingers).

To command the gripper using pre-configured poses (like Envelope Grasp, 3-Finger Pinch, etc.), check `instructions_sim.md` for the ready-to-use ROS 2 topic commands.

---

## Clean Shutdown

```bash
# 1. Stop active simulation processes: Ctrl+C in terminal
# 2. Stop Docker container from host:
./kairos.sh stop

# To remove persistent volumes (forces clean recompile next run):
docker compose down -v
```

---

## Troubleshooting

### ❌ "Cannot open display" / "No protocol specified"
```bash
xhost +local:docker
```

### ❌ Gazebo Simulation Stutter / High Lag
Run in low-performance mode or use the empty world:
```bash
./kairos.sh sim empty
```

### ❌ Shared Memory Lockup / FastRTPS Freezes
```bash
./kairos.sh clean
```

---

## Package Architecture

- `kairos_bringup`: Primary launch package (complete simulation, teleop, Nav2, gripper)
- `rbkairos_description`: RB-KAIROS+ URDF, Nav2 configurations, twist relay
- `tesollo_tactile_mock`: Mock tactile sensors for Tesollo hand
- `delto_m_ros2`: `dg_description` (URDF/meshes), `dg5f_gz` (Gazebo Harmonic plugin), `dg_msgs`
- `robotnik`: Simulation plugins, controller definitions, sensors, descriptions

---

*Author: Kamil BENMADI (<kamil.benmadi@sigma-clermont.fr>) — [GitHub](https://github.com/Uncrowned0x0) | [LinkedIn](https://www.linkedin.com/in/kamilb-)*
