#!/usr/bin/env bash
# ==============================================================================
# Author: Kamil BENMADI
# Email: kamil.benmadi@sigma-clermont.fr
# GitHub: https://github.com/Uncrowned0x0
# ==============================================================================
# =============================================================================
# kairos.sh — Convenience script for Kairos WS Light workspace
# RB-KAIROS Mobile Base + UR5e Arm + Tesollo DG-5F-R Gripper + Nav2 Simulation
#
# Usage:
#   ./kairos.sh <command> [options]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="kairos_sim"
ROS2_WS="/home/robot/ros2_ws"

# Terminal colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m' # No Color

info()    { echo -e "${BLUE}[kairos]${NC} $*" >&2; }
success() { echo -e "${GREEN}[kairos]${NC} $*" >&2; }
warn()    { echo -e "${YELLOW}[kairos]${NC} $*" >&2; }
error()   { echo -e "${RED}[kairos]${NC} $*" >&2; exit 1; }

# Detect if currently running inside the Docker container
is_inside_container() {
    [ -f /.dockerenv ] || [ -f /run/.containerenv ]
}

# Verify Docker installation and daemon accessibility
check_docker() {
    if is_inside_container; then
        return 0
    fi
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker Engine."
    fi
    if ! docker info &> /dev/null; then
        error "Docker daemon is not accessible. Try: sudo usermod -aG docker \$USER && newgrp docker"
    fi
}

# Automatically detect NVIDIA GPU acceleration
get_compose_files() {
    local compose_args=("-f" "${SCRIPT_DIR}/docker-compose.yaml")
    if [[ "${FORCE_CPU:-0}" == "1" ]]; then
        info "CPU mode forced by user."
    elif command -v nvidia-smi &> /dev/null && docker info 2>/dev/null | grep -iq "nvidia"; then
        compose_args+=("-f" "${SCRIPT_DIR}/docker-compose.gpu.yaml")
    elif command -v nvidia-smi &> /dev/null; then
        if docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q "nvidia"; then
            compose_args+=("-f" "${SCRIPT_DIR}/docker-compose.gpu.yaml")
        fi
    fi
    echo "${compose_args[@]}"
}

# Verify that the container is running (auto-start if stopped)
require_running() {
    if is_inside_container; then
        return 0
    fi
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        info "Container '${CONTAINER_NAME}' is not running. Starting container..."
        COMPOSE_ARGS=($(get_compose_files))
        cd "${SCRIPT_DIR}"
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose "${COMPOSE_ARGS[@]}" up -d
        sleep 2
    fi
}

# Execute a command inside the container as 'robot' user with ROS sourced
docker_exec() {
    if is_inside_container; then
        cd "${ROS2_WS}"
        set +u
        source /opt/ros/jazzy/setup.bash
        if [ -f "${ROS2_WS}/install/setup.bash" ]; then
            source "${ROS2_WS}/install/setup.bash"
        fi
        set -u
        eval "$*"
    else
        local it_flag=("-i")
        if [ -t 0 ] && [ -t 1 ]; then
            it_flag=("-it")
        fi
        docker exec "${it_flag[@]}" -u robot "${CONTAINER_NAME}" bash -c "cd ${ROS2_WS} && set +u && source /opt/ros/jazzy/setup.bash && if [ -f install/setup.bash ]; then source install/setup.bash; fi && set -u && $*"
    fi
}

# =============================================================================
CMD="${1:-help}"
shift || true

case "${CMD}" in

    # ── BUILD ────────────────────────────────────────────────────────────────
    build)
        if is_inside_container; then
            warn "You are currently running inside the Docker container. Build images from the host system."
            exit 0
        fi
        check_docker
        info "Building Docker image for Kairos WS Light..."
        COMPOSE_ARGS=($(get_compose_files))
        cd "${SCRIPT_DIR}"
        LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose "${COMPOSE_ARGS[@]}" build "$@"
        success "Docker image built successfully."
        info "Next steps: start container with './kairos.sh start' then compile with './kairos.sh colcon_build'."
        ;;

    # ── START ────────────────────────────────────────────────────────────────
    start)
        if is_inside_container; then
            info "You are already inside the running container."
            exit 0
        fi
        check_docker
        info "Starting container '${CONTAINER_NAME}'..."
        COMPOSE_ARGS=($(get_compose_files))
        cd "${SCRIPT_DIR}"
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose "${COMPOSE_ARGS[@]}" up -d
        success "Container started in background."
        info "To open a bash terminal: ./kairos.sh shell"
        ;;

    # ── STOP ─────────────────────────────────────────────────────────────────
    stop)
        if is_inside_container; then
            warn "You are inside the container. Exit first ('exit'), then run './kairos.sh stop' on host."
            exit 0
        fi
        check_docker
        info "Stopping container..."
        cd "${SCRIPT_DIR}"
        docker compose down
        success "Container stopped."
        ;;

    # ── RESTART ──────────────────────────────────────────────────────────────
    restart)
        if is_inside_container; then
            warn "To restart the container, exit first ('exit'), then run './kairos.sh restart' on host."
            exit 0
        fi
        check_docker
        info "Restarting container..."
        cd "${SCRIPT_DIR}"
        docker compose down
        COMPOSE_ARGS=($(get_compose_files))
        LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose "${COMPOSE_ARGS[@]}" up -d
        success "Container restarted."
        ;;

    # ── SHELL ────────────────────────────────────────────────────────────────
    shell)
        if is_inside_container; then
            info "You are already inside the container shell (user: $(whoami))."
            exit 0
        fi
        check_docker
        require_running
        info "Opening interactive bash shell in container (user: robot)..."
        docker exec -it -u robot "${CONTAINER_NAME}" bash
        ;;

    # ── COLCON BUILD ─────────────────────────────────────────────────────────
    colcon|colcon_build|colcon-build|build_ws|build-ws|compile)
        if [ "${1:-}" = "build" ]; then
            shift || true
        fi
        check_docker
        require_running
        info "Compiling ROS 2 workspace inside container..."
        docker_exec "colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release $*"
        success "Workspace built successfully."
        ;;

    # ── MODULAR WORKFLOW — TERMINAL 1: GAZEBO WORLD ──────────────────────────
    world)
        check_docker
        require_running
        WORLD="${1:-labo}"
        GUI="${2:-true}"
        info "Launching Gazebo world '${WORLD}' alone in Terminal 1 (GUI: ${GUI})..."
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        docker_exec "ros2 launch kairos_bringup kairos_world.launch.py world:=${WORLD} gui:=${GUI}"
        ;;

    # ── MODULAR WORKFLOW — TERMINAL 2: ROBOT SPAWN & RVIZ ─────────────────────
    robot)
        check_docker
        require_running
        GRIPPER="${1:-schunk_egk50}"
        RAW_RVIZ="${2:-true}"
        LOW_PERF="${3:-false}"
        case "$(echo "${RAW_RVIZ}" | tr '[:upper:]' '[:lower:]')" in
            false|0|no|norviz|no-rviz|no_rviz|none) RUN_RVIZ="false" ;;
            *) RUN_RVIZ="true" ;;
        esac
        if [[ "${GRIPPER}" != "schunk_egk50" && "${GRIPPER}" != "tesollo_dg5f" ]]; then
            warn "Unsupported gripper '${GRIPPER}'. Only 'schunk_egk50' and 'tesollo_dg5f' are supported. Defaulting to 'schunk_egk50'."
            GRIPPER="schunk_egk50"
        fi
        info "Spawning RB-KAIROS robot (Gripper: ${GRIPPER}, RViz: ${RUN_RVIZ}, Low-Perf: ${LOW_PERF}) in Terminal 2..."
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        docker_exec "ros2 launch kairos_bringup kairos_robot.launch.py gripper_type:=${GRIPPER} run_rviz:=${RUN_RVIZ} low_performance_simulation:=${LOW_PERF}"
        ;;

    # ── STANDALONE RVIZ2 ─────────────────────────────────────────────────────
    rviz)
        check_docker
        require_running
        RVIZ_CFG="${1:-}"
        info "Launching standalone RViz2..."
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        if [ -n "${RVIZ_CFG}" ]; then
            docker_exec "ros2 launch kairos_bringup kairos_rviz.launch.py rviz_config:=${RVIZ_CFG}"
        else
            docker_exec "ros2 launch kairos_bringup kairos_rviz.launch.py"
        fi
        ;;

    # ── COMBINED FULL SIMULATION (1-Terminal Shortcut) ────────────────────────
    sim)
        check_docker
        require_running
        WORLD="${1:-labo}"
        GRIPPER="${2:-schunk_egk50}"
        if [[ "${GRIPPER}" != "schunk_egk50" && "${GRIPPER}" != "tesollo_dg5f" ]]; then
            warn "Unsupported gripper '${GRIPPER}'. Only 'schunk_egk50' and 'tesollo_dg5f' are supported. Defaulting to 'schunk_egk50'."
            GRIPPER="schunk_egk50"
        fi
        info "Launching complete simulation (Gazebo + Robot + Nav2 + Gripper: ${GRIPPER}, World: ${WORLD})..."
        warn "Make sure the workspace is compiled: ./kairos.sh colcon_build"
        if [ -n "${DISPLAY:-}" ] && command -v xhost &>/dev/null; then
            xhost +local:docker >/dev/null 2>&1 || true
        fi
        docker_exec "ros2 launch kairos_bringup kairos_sim_complete.launch.py gripper_type:=${GRIPPER} world:=${WORLD}"
        ;;

    # ── MODULAR WORKFLOW — TERMINAL 3: TELEOP ────────────────────────────────
    teleop)
        check_docker
        require_running
        MODE="${1:-direct}"
        info "Launching RB-KAIROS keyboard teleoperation in Terminal 3..."
        info "Controls: Arrows (or Z/Q/S/D), Shift+Arrows (crabbing), +/- (speed), Space (emergency stop)"
        if [ "$MODE" = "xterm" ]; then
            info "Opening dedicated xterm window..."
            docker_exec "ros2 launch kairos_bringup kairos_teleop.launch.py use_xterm:=true"
        else
            info "Active control directly in this terminal (for xterm window: ./kairos.sh teleop xterm)..."
            docker_exec "ros2 launch kairos_bringup kairos_teleop.launch.py use_xterm:=false"
        fi
        ;;

    # ── MODULAR WORKFLOW — TERMINAL 3: NAV2 ──────────────────────────────────
    nav2)
        check_docker
        require_running
        info "Launching Nav2 autonomous navigation in Terminal 3 (Gazebo & robot must already be running)..."
        docker_exec "ros2 launch kairos_bringup kairos_nav2.launch.py"
        ;;

    # ── GRIPPER ──────────────────────────────────────────────────────────────
    gripper)
        check_docker
        require_running
        HAND="${1:-right}"
        info "Launching Tesollo DG-5F-R gripper controller (hand: ${HAND})..."
        info "Options: ./kairos.sh gripper right | left | both"
        docker_exec "ros2 launch kairos_bringup kairos_gripper.launch.py hand:=${HAND}"
        ;;

    # ── TEST ─────────────────────────────────────────────────────────────────
    test)
        check_docker
        require_running
        info "Running unit tests inside container..."
        docker_exec "python3 -m pytest src/kairos_bringup/test/ -o cache_dir=/tmp/.pytest_cache -v"
        ;;

    # ── CLEAN ────────────────────────────────────────────────────────────────
    clean)
        check_docker
        info "Cleaning FastRTPS shared memory and stale lockfiles..."
        rm -f /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* 2>/dev/null || true
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker exec -u root "${CONTAINER_NAME}" bash -c "rm -rf /dev/shm/fastrtps_* /dev/shm/sem.fastrtps_* /home/robot/.ros/log/* 2>/dev/null || true"
            docker exec -u root "${CONTAINER_NAME}" bash -c "pkill -9 -f rviz2 || true; pkill -9 -f gz || true; pkill -9 -f 'ros2 launch' || true; pkill -9 -f robot_state_publisher || true; pkill -9 -f parameter_bridge || true; pkill -9 -f spawner || true" 2>/dev/null || true
        fi
        success "Shared memory and residual processes cleaned."
        ;;

    # ── STATUS ───────────────────────────────────────────────────────────────
    status)
        check_docker
        echo -e "\n${BOLD}=== Container Status ===${NC}"
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        if command -v nvidia-smi &>/dev/null; then
            echo -e "\n${BOLD}=== NVIDIA GPU Status ===${NC}"
            nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader
        fi
        echo ""
        ;;

    # ── LOGS ─────────────────────────────────────────────────────────────────
    logs)
        check_docker
        info "Displaying container logs (Ctrl+C to quit)..."
        docker logs -f "${CONTAINER_NAME}"
        ;;

    # ── HELP ─────────────────────────────────────────────────────────────────
    help|--help|-h)
        cat <<EOF

${BLUE}╔══════════════════════════════════════════════════════════╗
║           Kairos WS Light — Management Script            ║
╚══════════════════════════════════════════════════════════╝${NC}

Usage: ${GREEN}./kairos.sh <command> [options]${NC}

Commands:
  ${YELLOW}build${NC}                     Build Docker image (first use or updates)
  ${YELLOW}start${NC}                     Start Docker container in background
  ${YELLOW}stop${NC}                      Stop Docker container
  ${YELLOW}restart${NC}                   Restart Docker container
  ${YELLOW}shell${NC}                     Open interactive bash shell inside container
  ${YELLOW}colcon_build [pkg]${NC}        Compile ROS 2 workspace inside container
  
  Modular Multi-Terminal Workflow:
  ${YELLOW}world [world] [gui]${NC}       Terminal 1: Launch Gazebo world alone (default: labo)
  ${YELLOW}robot [gripper] [rviz]${NC}    Terminal 2: Spawn RB-KAIROS robot + RViz2
                            gripper: schunk_egk50 (default) | tesollo_dg5f
                            rviz: true (default) | false
  ${YELLOW}rviz [config]${NC}             Terminal 2/4: Launch standalone RViz2
  ${YELLOW}teleop [direct|xterm]${NC}     Terminal 3: Keyboard teleoperation (crabbing, speeds, stop)
  ${YELLOW}nav2${NC}                      Terminal 3: Autonomous navigation stack (Nav2)
  
  All-in-One Shortcut:
  ${YELLOW}sim [world] [gripper]${NC}     Launch Gazebo + Robot + Nav2 + RViz in one terminal
                            world: labo (default) | empty | demo | lightweight_scene
                            gripper: schunk_egk50 (default) | tesollo_dg5f
  
  Utilities:
  ${YELLOW}gripper [hand]${NC}            Launch Tesollo DG-5F-R gripper controller (right|left|both)
  ${YELLOW}test${NC}                      Run unit test suite inside container
  ${YELLOW}clean${NC}                     Clean FastRTPS shared memory and stale processes
  ${YELLOW}status${NC}                    Show container and GPU status
  ${YELLOW}logs${NC}                      Display container logs
  ${YELLOW}help${NC}                      Display this help message

Recommended Modular Workflow:
  Terminal 0 (Host once): ${GREEN}xhost +local:docker && ./kairos.sh start${NC}
  Terminal 1:             ${GREEN}./kairos.sh world labo${NC}
  Terminal 2:             ${GREEN}./kairos.sh robot schunk_egk50${NC}   (or tesollo_dg5f)
  Terminal 3:             ${GREEN}./kairos.sh teleop${NC}               (or ./kairos.sh nav2)

Documentation:
  README.md         Complete technical guide
  BEGINNER_GUIDE.md Step-by-step beginner guide with raw terminal commands

EOF
        ;;

    # ── UNKNOWN COMMAND ──────────────────────────────────────────────────────
    *)
        error "Unknown command: '${CMD}'. Use './kairos.sh help' to see available options."
        ;;

esac
