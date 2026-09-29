<!-- 
==============================================================================
Author: Kamil BENMADI
Email: kamil.benmadi@sigma-clermont.fr
GitHub: https://github.com/Uncrowned0x0
==============================================================================
-->

# 🎓 Beginner's Step-by-Step Guide — RB-KAIROS+ Simulation (ROS 2 Jazzy & Gazebo Harmonic)

> **Who is this guide for?**  
> This guide is written for anyone starting with **ROS 2**, **Gazebo**, and **Docker**. All commands are provided as **raw, standard terminal commands** (no wrapper scripts required), making them directly reproducible on any system or GitHub repository.

---

## 📋 Table of Contents

- [Step 0 — Overview & Architecture](#step-0--overview--architecture)
- [Step 1 — Verify Host Prerequisites](#step-1--verify-host-prerequisites)
- [Step 2 — Install Docker & Docker Compose (If Needed)](#step-2--install-docker--docker-compose-if-needed)
- [Step 3 — Authorize 3D GUI Display (X11)](#step-3--authorize-3d-gui-display-x11)
- [Step 4 — Build the Docker Image](#step-4--build-the-docker-image)
- [Step 5 — Start the Container](#step-5--start-the-container)
- [Step 6 — Compile the ROS 2 Workspace (Colcon Build)](#step-6--compile-the-ros-2-workspace-colcon-build)
- [Step 7 — Launch Full Gazebo Simulation](#step-7--launch-full-gazebo-simulation)
- [Step 8 — Interactive Keyboard Teleoperation (Arrow Keys)](#step-8--interactive-keyboard-teleoperation-arrow-keys)
- [Step 9 — Autonomous Navigation with Nav2](#step-9--autonomous-navigation-with-nav2)
- [Step 10 — Control the Tesollo DG-5F-R 5-Finger Hand](#step-10--control-the-tesollo-dg-5f-r-5-finger-hand)
- [Step 11 — Clean Shutdown & Container Teardown](#step-11--clean-shutdown--container-teardown)
- [❓ FAQ & Common Issues](#-faq--common-issues)

---

## Step 0 — Overview & Architecture

### What is the RB-KAIROS+?
The **RB-KAIROS+** is an industrial mobile manipulator created by Robotnik:
1. **Omnidirectional Mobile Base**: 4 Mecanum wheels allowing omnidirectional translation (forward/backward, crabbing sideways) and rotation.
2. **Robotic Arm**: Universal Robots **UR5e** (6 Degrees of Freedom).
3. **End-Effector**: **Tesollo DG-5F-R** dexterous hand (5 fingers, 20 active joints, tactile sensor support).

### Why Docker?
Docker creates an isolated, self-contained environment containing Ubuntu 24.04, ROS 2 Jazzy, Gazebo Harmonic, Nav2, and all required controllers without altering your host system.

---

## Step 1 — Verify Host Prerequisites

Open a terminal on your host machine (`Ctrl+Alt+T`) and run:

```bash
# 1. Verify Ubuntu version
lsb_release -a
# Recommended: Ubuntu 22.04 or 24.04

# 2. Check Docker installation
docker --version
# Expected: Docker version 24.x.x or newer

# 3. Check Docker Compose (v2 plugin)
docker compose version
# Expected: Docker Compose version v2.x.x
```

- ❌ If Docker is **not installed** → **Proceed to Step 2**
- ✅ If Docker is **already installed** → **Skip directly to Step 3**

---

## Step 2 — Install Docker & Docker Compose (If Needed)

Run the following commands on your host system:

```bash
# 1. Update package index and install required tools
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 2. Add Docker official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 3. Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine and Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 5. Enable non-root Docker usage for your user account
sudo usermod -aG docker $USER
newgrp docker
```

---

## Step 3 — Authorize 3D GUI Display (X11)

Gazebo Harmonic and RViz2 run inside the container but display their 3D graphics on your host screen via the X11 server. You must authorize container display connections:

```bash
# Authorize local container connections to the X11 server
xhost +local:docker
```

> 💡 **Tip:** To avoid running this command each time you reboot, append it to your `~/.bashrc`:
> ```bash
> echo "xhost +local:docker >/dev/null 2>&1" >> ~/.bashrc
> ```

---

## Step 4 — Build the Docker Image

Navigate to your workspace directory on the host:

```bash
cd /home/YourMachine/kairos_ws_light
```

Build the container image using standard `docker compose`:

```bash
# Standard build (matches current user UID/GID to avoid permission issues)
LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose build
```

> ⏳ *Estimated build time: 3 to 10 minutes on first build (subsequent builds are instantaneous thanks to layer caching).*

---

## Step 5 — Start the Container

Start the simulation container in background daemon mode:

```bash
# Start container (with automatic NVIDIA GPU acceleration if available)
docker compose up -d
```

Verify that the container is running:

```bash
docker ps --filter "name=kairos_sim"
```
You should see `kairos_sim` with status `Up`.

---

## Step 6 — Compile the ROS 2 Workspace (Colcon Build)

Open an interactive bash terminal inside the container:

```bash
docker exec -it -u robot kairos_sim bash
```

Your shell prompt is now `robot@...:~/ros2_ws$`. Run the standard colcon build:

```bash
# Inside the container:
cd /home/robot/ros2_ws
source /opt/ros/jazzy/setup.bash

# Build all packages
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release

# Source workspace install overlay
source install/setup.bash
```

> 💡 *All 29 packages should compile with zero errors.*  
> You can now either remain inside this container terminal or type `exit` to return to your host terminal.

---

---

## Step 7 — Modular Multi-Terminal Workflow (Recommended)

To achieve maximum modularity, stability, and clean debugging, the simulation is split across separate terminals:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       MODULAR MULTI-TERMINAL ARCHITECTURE                   │
│                                                                             │
│   Terminal 1: Gazebo World Server & GUI (/clock + physics)                  │
│       │                                                                     │
│   Terminal 2: RB-KAIROS Robot Spawn + Controllers + RViz2                   │
│       │                                                                     │
│   Terminal 3: Navigation (Nav2 Stack) OR Keyboard Teleoperation             │
└─────────────────────────────────────────────────────────────────────────────┘
```

>  **NVIDIA GPU Acceleration (Fixed 5 FPS Bottleneck):**  
> `docker-compose.yaml` contains direct NVIDIA GPU hardware acceleration reservations (`deploy.resources.reservations.devices` and `runtime: nvidia`). Gazebo Harmonic uses Ogre 2.x on your RTX 4070 GPU rather than falling back to CPU software rasterization (`llvmpipe`), ensuring smooth 60 FPS real-time rendering even with LiDAR and cameras enabled.

### 🖥️ Terminal 1 — Start Gazebo Simulation World

In your first terminal on the host, launch the Gazebo simulation world alone (default: `labo`):

**Raw Terminal Command:**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_world.launch.py world:=labo"
```

*Or via convenience wrapper:*
```bash
./kairos.sh world labo
```

> **Available world options:** `world:=labo` (default), `world:=empty`, `world:=demo`, `world:=lightweight_scene`.

---

### 🤖 Terminal 2 — Spawn Robot, Controllers & RViz2

Open a **second terminal** on your host machine to spawn the RB-KAIROS robot and its controllers.

> ✋ **Strict Gripper Filtering:**  
> The simulation supports **only two end-effectors**:
> 1. `schunk_egk50` — Schunk 2-finger parallel gripper (default)
> 2. `tesollo_dg5f` — Tesollo DG-5F-R 5-finger dexterous hand with 20 DOFs  
> *(Obsolete grippers `qbhand` and `onrobot_rg6` are completely disabled).*

**Raw Terminal Command (with Schunk EGK50 Gripper):**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_robot.launch.py gripper_type:=schunk_egk50"
```

**Raw Terminal Command (with Tesollo DG-5F-R Hand):**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_robot.launch.py gripper_type:=tesollo_dg5f"
```

*Or via convenience wrapper:*
```bash
./kairos.sh robot schunk_egk50
# or
./kairos.sh robot tesollo_dg5f
```

*(Optional: If you wish to launch RViz2 in its own dedicated terminal, pass `run_rviz:=false` to `kairos_robot.launch.py`, then run: `ros2 launch kairos_bringup kairos_rviz.launch.py` or `./kairos.sh rviz`).*

---

### 🧭 Terminal 3 — Navigation (Nav2) OR Keyboard Teleoperation

Open a **third terminal** on your host machine. Depending on what you want to test, choose **Option 3A** (Nav2) or **Option 3B** (Keyboard Teleop):

#### Option 3A: Autonomous Navigation (Nav2 Stack)
Once the robot is spawned in Terminal 2, start the full Nav2 navigation stack:

**Raw Terminal Command:**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_nav2.launch.py"
```

*Or via convenience wrapper:*
```bash
./kairos.sh nav2
```

To send a navigation goal:
1. In the RViz2 window, click the **Nav2 Goal** tool on the top toolbar.
2. Click anywhere on the map and drag the green orientation arrow.
3. The robot will plan a path and navigate smoothly to the destination!

#### Option 3B: Interactive Keyboard Teleoperation
To drive the omnidirectional base manually:

**Raw Terminal Command:**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_teleop.launch.py"
```

*Or via convenience wrapper:*
```bash
./kairos.sh teleop
```

---

## Manual Arm and Gripper Control (Command Line)

You can directly command the UR5e robotic arm and the Tesollo DG-5F-R hand using raw ROS 2 topic commands. 
To do this, open a new terminal and follow these steps:

### Controlling the UR5e Arm

**Step 1: Enter the running container**
```bash
docker exec -it -u robot kairos_sim bash
```

**Step 2: Source the ROS 2 workspace**
```bash
source /opt/ros/jazzy/setup.bash
source /home/robot/ros2_ws/install/setup.bash
```

**Step 3: Publish the `JointTrajectory` command**  
Choose any of the following pre-made poses and copy-paste the command.

*(1) Home / Upright Pose:*
```bash
ros2 topic pub /robot/arm_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['robot_arm_shoulder_pan_joint', 'robot_arm_shoulder_lift_joint', 'robot_arm_elbow_joint', 'robot_arm_wrist_1_joint', 'robot_arm_wrist_2_joint', 'robot_arm_wrist_3_joint'], points: [{positions: [0.0, -1.57, 0.0, -1.57, 0.0, 0.0], time_from_start: {sec: 3, nanosec: 0}}]}" -1
```

*(2) Folded / Rest Pose:*
```bash
ros2 topic pub /robot/arm_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['robot_arm_shoulder_pan_joint', 'robot_arm_shoulder_lift_joint', 'robot_arm_elbow_joint', 'robot_arm_wrist_1_joint', 'robot_arm_wrist_2_joint', 'robot_arm_wrist_3_joint'], points: [{positions: [0.0, -2.79, 2.61, -2.96, -1.57, 0.0], time_from_start: {sec: 3, nanosec: 0}}]}" -1
```

*(3) Ready / Observe Pose:*
```bash
ros2 topic pub /robot/arm_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['robot_arm_shoulder_pan_joint', 'robot_arm_shoulder_lift_joint', 'robot_arm_elbow_joint', 'robot_arm_wrist_1_joint', 'robot_arm_wrist_2_joint', 'robot_arm_wrist_3_joint'], points: [{positions: [0.0, -1.57, 1.57, -1.57, -1.57, 0.0], time_from_start: {sec: 3, nanosec: 0}}]}" -1
```

### Controlling the Tesollo DG-5F-R Hand

If you launched the robot with `gripper_type:=tesollo_dg5f`, you can actuate the 20-DOF hand.

**Step 1: Enter the running container**
```bash
docker exec -it -u robot kairos_sim bash
```

**Step 2: Source the ROS 2 workspace**
```bash
source /opt/ros/jazzy/setup.bash
source /home/robot/ros2_ws/install/setup.bash
```

**Step 3: Publish the `JointTrajectory` command**  
Choose any of the following pre-made poses extracted from your DGManager presets and copy-paste the command.

*(1) Home / Fully Open (Main Ouverte):*
```bash
ros2 topic pub /robot/tesollo_dg5f_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['rj_dg_1_1', 'rj_dg_1_2', 'rj_dg_1_3', 'rj_dg_1_4', 'rj_dg_2_1', 'rj_dg_2_2', 'rj_dg_2_3', 'rj_dg_2_4', 'rj_dg_3_1', 'rj_dg_3_2', 'rj_dg_3_3', 'rj_dg_3_4', 'rj_dg_4_1', 'rj_dg_4_2', 'rj_dg_4_3', 'rj_dg_4_4', 'rj_dg_5_1', 'rj_dg_5_2', 'rj_dg_5_3', 'rj_dg_5_4'], points: [{positions: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], time_from_start: {sec: 2, nanosec: 0}}]}" -1
```

*(2) Envelope Grasp (Saisie Enveloppante):*
```bash
ros2 topic pub /robot/tesollo_dg5f_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['rj_dg_1_1', 'rj_dg_1_2', 'rj_dg_1_3', 'rj_dg_1_4', 'rj_dg_2_1', 'rj_dg_2_2', 'rj_dg_2_3', 'rj_dg_2_4', 'rj_dg_3_1', 'rj_dg_3_2', 'rj_dg_3_3', 'rj_dg_3_4', 'rj_dg_4_1', 'rj_dg_4_2', 'rj_dg_4_3', 'rj_dg_4_4', 'rj_dg_5_1', 'rj_dg_5_2', 'rj_dg_5_3', 'rj_dg_5_4'], points: [{positions: [0.35, -1.66, 0.17, 0.96, 0.09, 0.70, 0.52, 0.52, 0.17, 0.79, 0.70, 0.17, 0.44, 0.70, 0.61, 0.52, 0.09, 0.61, 1.05, 0.52], time_from_start: {sec: 2, nanosec: 0}}]}" -1
```

*(3) Fine Pinch Thumb/Index (Pince Fine):*
```bash
ros2 topic pub /robot/tesollo_dg5f_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{joint_names: ['rj_dg_1_1', 'rj_dg_1_2', 'rj_dg_1_3', 'rj_dg_1_4', 'rj_dg_2_1', 'rj_dg_2_2', 'rj_dg_2_3', 'rj_dg_2_4', 'rj_dg_3_1', 'rj_dg_3_2', 'rj_dg_3_3', 'rj_dg_3_4', 'rj_dg_4_1', 'rj_dg_4_2', 'rj_dg_4_3', 'rj_dg_4_4', 'rj_dg_5_1', 'rj_dg_5_2', 'rj_dg_5_3', 'rj_dg_5_4'], points: [{positions: [0.0, -1.57, 0.35, 0.79, -0.17, 0.35, 0.96, 0.61, 0.0, 0.52, 0.87, 0.70, -0.09, 1.40, 1.57, 0.70, 0.0, -0.17, 1.57, 1.48], time_from_start: {sec: 2, nanosec: 0}}]}" -1
```

---

## Alternative: All-in-One Simulation (1-Terminal Shortcut)

If you prefer to start Gazebo, the robot, Nav2, and RViz in a single command:

**Raw Terminal Command:**
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_sim_complete.launch.py world:=labo gripper_type:=schunk_egk50"
```

*Or via convenience wrapper:*
```bash
./kairos.sh sim labo schunk_egk50
```

---

## Step 8 — Interactive Keyboard Teleoperation Controls Reference

| Key | Motion | Action |
|---|---|---|
| **▲ Up Arrow** (or `Z`/`W`/`I`) | **Forward** | Linear velocity forward ($+v_x$) |
| **▼ Down Arrow** (or `S`/`K`) | **Backward** | Linear velocity backward ($-v_x$) |
| **◄ Left Arrow** (or `Q`/`A`/`J`) | **Turn Left** | Counter-clockwise yaw rotation ($+\omega_z$) |
| **► Right Arrow** (or `D`/`L`) | **Turn Right** | Clockwise yaw rotation ($-\omega_z$) |
| **Shift + ◄ / ►** (or `U`/`O`) | **Strafe** | Mecanum lateral crabbing ($+v_y$ / $-v_y$) |
| **`+`** (or `P`) | **Speed Up** | $+0.02\text{ m/s}$ (Up to maximum ceiling) |
| **`-`** (or `M`) | **Speed Down** | $-0.02\text{ m/s}$ (Down to minimum threshold) |
| **Space** (or `X`/`C`) | **Emergency Stop** | Immediate halt ($0\text{ m/s}$) |
| **Esc** / `Ctrl+C` | **Quit** | Safe exit with zero command broadcast |

> 🛡️ **Deadman Switch Safety**: Releasing motion keys automatically halts the base in $0.60\text{ s}$ to prevent runaway motion while accommodating keyboard typematic repeat delay.

---

## Step 9 — Autonomous Navigation with Nav2

Nav2 is automatically active when launching `kairos_sim_complete.launch.py`.

### How to send an autonomous navigation goal in RViz2:
1. In the top toolbar of the RViz2 window, click the **Nav2 Goal** (or **2D Goal Pose**) tool.
2. Click anywhere on the map floor in the direction you want the robot to face, then drag the green arrow to set the final orientation.
3. Release the mouse: Nav2 costmaps calculate the obstacle-free path and the omnidirectional base navigates autonomously to the target!

### Standalone Nav2 Launch (if launching components separately):
```bash
docker exec -it -u robot kairos_sim bash -c "source /opt/ros/jazzy/setup.bash && source /home/robot/ros2_ws/install/setup.bash && ros2 launch kairos_bringup kairos_nav2.launch.py"
```

---

## Step 10 — Control the Tesollo DG-5F-R 5-Finger Hand

The Tesollo DG-5F-R hand has 20 motorized joints (`rj_dg_1_1` to `rj_dg_5_4`) driven by `tesollo_dg5f_controller`.

### Send joint position commands via ROS 2 topic:

```bash
# Open a terminal inside the container:
docker exec -it -u robot kairos_sim bash
source install/setup.bash

# 1. Close all fingers (grasp pose)
ros2 topic pub /robot/tesollo_dg5f_controller/commands std_msgs/msg/Float64MultiArray \
  "{data: [0.5, 0.8, 0.8, 0.8,  0.5, 0.8, 0.8, 0.8,  0.5, 0.8, 0.8, 0.8,  0.5, 0.8, 0.8, 0.8,  0.5, 0.8, 0.8, 0.8]}" -1

# 2. Open all fingers (open hand pose)
ros2 topic pub /robot/tesollo_dg5f_controller/commands std_msgs/msg/Float64MultiArray \
  "{data: [0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0, 0.0]}" -1
```

---

## Step 11 — Clean Shutdown & Container Teardown

1. Stop running nodes in your simulation and teleoperation terminals with `Ctrl+C`.
2. Stop the background Docker container from your host machine:

```bash
cd /home/YourMachine/kairos_ws_light
docker compose down
```

---

## ❓ FAQ & Common Issues

### Q1: "Cannot open display" or black Gazebo window?
Run on host:
```bash
xhost +local:docker
```

### Q2: Can I edit source code on my host machine?
**Yes.** The `./src` folder is bind-mounted directly to `/home/robot/ros2_ws/src`. Any modification in your host IDE (VS Code, Cursor, etc.) is immediately visible inside the container. After modifying C++ or message definitions, simply re-run `colcon build` inside the container.

### Q3: How to clean stale shared memory after an improper kill?
```bash
docker exec -u root kairos_sim rm -rf /dev/shm/* /home/robot/.ros/log/*
```

---

*Author: Kamil BENMADI (<kamil.benmadi@sigma-clermont.fr>) — [GitHub](https://github.com/Uncrowned0x0) | [LinkedIn](https://www.linkedin.com/in/kamilb-)*
