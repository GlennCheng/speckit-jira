#!/usr/bin/env bash
#
# install.sh — Specrity Installer
#
# Deploy specrity workflow prompts to various AI tool directories.
# Based on spec-kit's agent registry pattern, supports 17+ LLM tools.
#
# Usage:
#   ./install.sh                    # Interactive mode
#   ./install.sh cursor-agent       # Install to Cursor
#   ./install.sh claude agy         # Install to multiple tools
#   ./install.sh --all              # Install to all detected tools
#   ./install.sh --help             # Show help
#

set -euo pipefail

# ─── Version ───
VERSION="0.1.0"

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Helpers ───
log_info()    { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_ok()      { echo -e "${GREEN}✅ $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error()   { echo -e "${RED}❌ $*${NC}"; }
log_header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}\n"; }

# ─── Agent Registry ───
# Format: KEY|DISPLAY_NAME|TARGET_PATH|FORMAT_TYPE
# FORMAT_TYPE: cli_single (single merged md), ide_frontmatter (with frontmatter), agy_copy (direct copy)
declare -a AGENT_REGISTRY=(
    "claude|Claude Code (CLI)|CLAUDE.md|cli_single"
    "gemini|Gemini CLI|GEMINI.md|cli_single"
    "copilot|GitHub Copilot|.github/agents/copilot-instructions.md|cli_single"
    "cursor-agent|Cursor IDE|.cursor/rules/specrity.mdc|ide_frontmatter"
    "windsurf|Windsurf|.windsurf/rules/specrity.md|ide_frontmatter"
    "agy|Antigravity|.agents/workflows/|agy_copy"
    "qwen|Qwen Code|QWEN.md|cli_single"
    "opencode|opencode|AGENTS.md|cli_single"
    "codex|Codex CLI|AGENTS.md|cli_single"
    "kilocode|Kilo Code|.kilocode/rules/specrity.md|ide_frontmatter"
    "auggie|Auggie CLI|.augment/rules/specrity.md|ide_frontmatter"
    "roo|Roo Code|.roo/rules/specrity.md|ide_frontmatter"
    "codebuddy|CodeBuddy CLI|CODEBUDDY.md|cli_single"
    "amp|Amp|AGENTS.md|cli_single"
    "shai|SHAI|SHAI.md|cli_single"
    "q|Amazon Q CLI|AGENTS.md|cli_single"
    "bob|IBM Bob|AGENTS.md|cli_single"
)

# ─── Globals ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="${SCRIPT_DIR}/workflows"
PROJECT_ROOT=""
SELECTED_AGENTS=()

# ─── Functions ───

show_help() {
    cat <<EOF
${BOLD}specrity install${NC} v${VERSION}

Deploy specrity workflow prompts to your AI coding tools.

${BOLD}USAGE${NC}
    ./install.sh                    Interactive mode
    ./install.sh <agent> [agent...] Install to specific agents
    ./install.sh --all              Install to all detected agents
    ./install.sh --help             Show this help
    ./install.sh --list             List all supported agents

${BOLD}SUPPORTED AGENTS${NC}
EOF
    for entry in "${AGENT_REGISTRY[@]}"; do
        IFS='|' read -r key name target_path _ <<< "$entry"
        printf "    ${GREEN}%-16s${NC} %s → %s\n" "$key" "$name" "$target_path"
    done
    cat <<EOF

${BOLD}EXAMPLES${NC}
    ./install.sh cursor-agent       Install to Cursor IDE
    ./install.sh claude agy         Install to Claude Code + Antigravity
    ./install.sh --all              Install to all agents

${BOLD}ENVIRONMENT${NC}
    The installer will set up .specrity.yml (project config).
    Workflow files are deployed locally and NOT committed to git.

    To set up spec submodule (recommended for teams):
    git submodule add <remote-url> specs/

EOF
    exit 0
}

show_list() {
    echo -e "${BOLD}Supported AI Agents:${NC}\n"
    for entry in "${AGENT_REGISTRY[@]}"; do
        IFS='|' read -r key name target_path format_type <<< "$entry"
        printf "  ${GREEN}%-16s${NC} %-24s → %-40s ${DIM}[%s]${NC}\n" "$key" "$name" "$target_path" "$format_type"
    done
    echo ""
    exit 0
}

find_project_root() {
    local dir
    dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            PROJECT_ROOT="$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    log_error "Could not find a git repository. Please run this script from within a git project."
    exit 1
}

get_agent_entry() {
    local search_key="$1"
    for entry in "${AGENT_REGISTRY[@]}"; do
        IFS='|' read -r key _ _ _ <<< "$entry"
        if [[ "$key" == "$search_key" ]]; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

# ─── Interactive Agent Selection ───
select_agents_interactive() {
    echo -e "${BOLD}Select AI agents to install to:${NC}\n"

    local i=1
    local keys=()
    for entry in "${AGENT_REGISTRY[@]}"; do
        IFS='|' read -r key name _ _ <<< "$entry"
        printf "  ${CYAN}%2d${NC}) %-16s %s\n" "$i" "$key" "$name"
        keys+=("$key")
        ((i++))
    done

    echo ""
    echo -e "  ${CYAN} a${NC}) All agents"
    echo -e "  ${CYAN} q${NC}) Quit"
    echo ""
    read -rp "Enter numbers separated by spaces (e.g., 1 3 6): " choices

    if [[ "$choices" == "q" || "$choices" == "Q" ]]; then
        echo "Cancelled."
        exit 0
    fi

    if [[ "$choices" == "a" || "$choices" == "A" ]]; then
        SELECTED_AGENTS=("${keys[@]}")
        return
    fi

    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#keys[@]} )); then
            SELECTED_AGENTS+=("${keys[$((choice-1))]}")
        else
            log_warn "Invalid selection: $choice (skipping)"
        fi
    done

    if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
        log_error "No agents selected."
        exit 1
    fi
}

# ─── Project Configuration Setup ───
setup_project_config() {
    local target_dir="${PROJECT_ROOT}/.specrity"
    mkdir -p "$target_dir"

    # Migrate from old root location if present
    if [[ -f "${PROJECT_ROOT}/.specrity.yml" ]] && [[ ! -f "${target_dir}/.specrity.yml" ]]; then
        mv "${PROJECT_ROOT}/.specrity.yml" "${target_dir}/.specrity.yml"
        log_info "Migrated .specrity.yml to .specrity/ directory"
    fi

    local config_file="${target_dir}/.specrity.yml"

    log_header "Project Configuration"

    # Check if config already exists
    if [[ -f "$config_file" ]]; then
        echo -e "  Found existing ${CYAN}.specrity/.specrity.yml${NC}:"
        echo ""
        sed 's/^/    /' "$config_file" | grep -v '^    #' | grep -v '^$' | head -10
        echo ""
        read -rp "Keep current config? [Y/n]: " keep
        if [[ "${keep,,}" != "n" ]]; then
            log_ok "Using existing configuration"
            return
        fi
    fi

    # Ask spec_mode
    echo -e "  ${BOLD}Where should PRD documents be stored?${NC}"
    echo ""
    echo -e "  ${CYAN}1${NC}) ${BOLD}local${NC}      — In the project directory (simplest, default)"
    echo -e "                 PRDs saved to ${DIM}./specrity/drafts/...${NC}"
    echo ""
    echo -e "  ${CYAN}2${NC}) ${BOLD}submodule${NC}  — In a git submodule (recommended for teams)"
    echo -e "                 Separate repo, auto-synced via git submodule"
    echo ""
    echo -e "  ${CYAN}3${NC}) ${BOLD}external${NC}   — In a completely separate repo"
    echo -e "                 Each person sets their own path in .env"
    echo ""
    read -rp "Choose [1/2/3] (default: 1): " mode_choice

    local spec_mode="local"
    local spec_path="specrity/"

    case "${mode_choice}" in
        2)
            spec_mode="submodule"
            read -rp "Submodule relative path (default: specrity/): " sub_path
            spec_path="${sub_path:-specrity/}"
            # Check if submodule exists
            # Note: .git in submodule can be a FILE (not dir), containing "gitdir: ..."
            local spec_path_clean="${spec_path%/}"  # strip trailing slash
            if [[ ! -e "${PROJECT_ROOT}/${spec_path_clean}/.git" ]] && ! git -C "$PROJECT_ROOT" submodule status 2>/dev/null | grep -q "${spec_path_clean}"; then
                echo ""
                log_error "Submodule not found at '${spec_path}'."
                echo ""
                echo -e "  ${BOLD}Please set up the Spec Submodule first, then re-run install.sh:${NC}"
                echo ""
                echo -e "  ${CYAN}# Step 1: Create a new repo on GitHub/GitLab (e.g. my-project-specs)${NC}"
                echo ""
                echo -e "  ${CYAN}# Step 2: Add it as a submodule in your project${NC}"
                echo -e "  ${YELLOW}cd ${PROJECT_ROOT}${NC}"
                echo -e "  ${YELLOW}git submodule add git@github.com:your-org/my-project-specs.git ${spec_path}${NC}"
                echo -e "  ${YELLOW}git commit -m \"chore: add spec submodule\"${NC}"
                echo -e "  ${YELLOW}git push${NC}"
                echo ""
                echo -e "  ${CYAN}# Step 3: Re-run the installer${NC}"
                echo -e "  ${YELLOW}$0 $*${NC}"
                echo ""
                echo -e "  ${BOLD}Or choose local mode instead (no extra repo needed):${NC}"
                echo -e "  Re-run install.sh and select ${CYAN}1) local${NC}"
                echo ""
                exit 1
            fi
            ;;
        3)
            spec_mode="external"
            read -rp "Spec repo absolute path: " ext_path
            # Write .env for external mode
            local env_file="${PROJECT_ROOT}/.env"
            cat > "$env_file" <<ENVEOF
# Specrity External Spec Repo
# Generated by install.sh on $(date -Iseconds)
SPEC_REPO_PATH=${ext_path}
ENVEOF
            log_ok "External path saved to .env"
            # Add .env to .gitignore if not already there
            if [[ -f "${PROJECT_ROOT}/.gitignore" ]] && ! grep -q "^\.env$" "${PROJECT_ROOT}/.gitignore"; then
                echo ".env" >> "${PROJECT_ROOT}/.gitignore"
                log_ok "Added .env to .gitignore"
            fi
            ;;
        *)
            spec_mode="local"
            read -rp "Spec directory relative path (default: specs/): " local_path
            spec_path="${local_path:-specs/}"
            ;;
    esac

    # Optionally ask Jira settings
    local jira_cloud_id=""
    local jira_project_key=""

    echo ""
    read -rp "Set Jira Cloud ID? (leave empty to auto-detect via MCP): " jira_cloud_id
    read -rp "Set default Project Key? (leave empty to parse from ticket ID): " jira_project_key

    # Ask about protected branches
    echo ""
    echo -e "  ${BOLD}Branch Protection${NC}"
    echo -e "  Default protected branches: ${CYAN}main, master, develop, integration, staging, production, release/*${NC}"
    read -rp "Add extra protected branches? (comma-separated, or Enter to keep defaults): " extra_branches

    # Generate .specrity.yml
    cat > "$config_file" <<CFGEOF
# Specrity Project Configuration
# Generated by install.sh v${VERSION} on $(date -Iseconds)
# This file should be committed to your repo.

spec_mode: ${spec_mode}
spec_path: ${spec_path}

# Branches that workflows must NEVER push to.
# Prevents accidental pushes to CI/CD environment branches.
protected_branches:
  - main
  - master
  - develop
  - integration
  - staging
  - production
  - release/*
CFGEOF

    # Add extra protected branches
    if [[ -n "$extra_branches" ]]; then
        IFS=',' read -ra EXTRA <<< "$extra_branches"
        for branch in "${EXTRA[@]}"; do
            branch=$(echo "$branch" | xargs)  # trim whitespace
            echo "  - ${branch}" >> "$config_file"
        done
    fi

    # Add optional Jira settings
    if [[ -n "$jira_cloud_id" || -n "$jira_project_key" ]]; then
        echo "" >> "$config_file"
        [[ -n "$jira_cloud_id" ]] && echo "jira_cloud_id: ${jira_cloud_id}" >> "$config_file"
        [[ -n "$jira_project_key" ]] && echo "jira_project_key: ${jira_project_key}" >> "$config_file"
    fi

    log_ok "Configuration saved to .specrity.yml"
    echo ""
    echo -e "  ${YELLOW}📌 Remember to commit this file:${NC}"
    echo -e "  ${CYAN}git add .specrity.yml && git commit -m \"chore: add specrity config\"${NC}"

    # Create spec directory if local mode
    if [[ "$spec_mode" == "local" ]]; then
        mkdir -p "${PROJECT_ROOT}/${spec_path}"
        log_ok "Created spec directory: ${spec_path}"
    fi
}

# ─── Format & Deploy ───

# Generate the merged content for CLI-type agents (single file with all workflows)
generate_cli_single_content() {
    cat <<HEADER
# Specrity Workflows

> Auto-generated by specrity install.sh v${VERSION}
> Generated: $(date -Iseconds)

These are AI agent workflow commands for Jira-integrated development.
Use the slash commands below to trigger each workflow.

---

HEADER

    for workflow_file in "${WORKFLOWS_DIR}"/*.md; do
        if [[ -f "$workflow_file" ]]; then
            local basename
            basename=$(basename "$workflow_file" .md)
            echo "## /${basename}"
            echo ""
            # Strip YAML frontmatter
            sed '1{/^---$/!b};1,/^---$/d' "$workflow_file"
            echo ""
            echo "---"
            echo ""
        fi
    done
}

# Generate content for IDE-type agents (with frontmatter)
generate_ide_frontmatter_content() {
    local agent_key="$1"

    # Cursor uses .mdc format with specific frontmatter
    if [[ "$agent_key" == "cursor-agent" ]]; then
        cat <<MDC_HEADER
---
description: Specrity workflow commands for Jira-integrated development
globs:
alwaysApply: false
---

MDC_HEADER
    else
        cat <<MD_HEADER
---
description: Specrity workflow commands for Jira-integrated development
---

MD_HEADER
    fi

    generate_cli_single_content | tail -n +8  # Skip the header that's replaced by frontmatter
}

# Deploy workflows for Antigravity (direct copy, one file per workflow)
deploy_agy_copy() {
    local target_dir="${PROJECT_ROOT}/.agents/workflows"
    mkdir -p "$target_dir"

    for workflow_file in "${WORKFLOWS_DIR}"/*.md; do
        if [[ -f "$workflow_file" ]]; then
            local basename
            basename=$(basename "$workflow_file")
            cp "$workflow_file" "${target_dir}/${basename}"
            log_ok "  Copied ${basename} → ${target_dir}/${basename}"
        fi
    done
}

deploy_agent() {
    local entry="$1"
    IFS='|' read -r key name target_path format_type <<< "$entry"

    log_info "Deploying to ${BOLD}${name}${NC} (${key})"

    case "$format_type" in
        cli_single)
            local full_path="${PROJECT_ROOT}/${target_path}"
            local dir
            dir=$(dirname "$full_path")
            mkdir -p "$dir"

            # If target file already exists (shared like AGENTS.md), append
            if [[ -f "$full_path" ]] && ! grep -q "Specrity Workflows" "$full_path" 2>/dev/null; then
                echo "" >> "$full_path"
                echo "---" >> "$full_path"
                echo "" >> "$full_path"
                generate_cli_single_content >> "$full_path"
                log_ok "  Appended to ${target_path}"
            elif [[ -f "$full_path" ]] && grep -q "Specrity Workflows" "$full_path" 2>/dev/null; then
                log_warn "  ${target_path} already contains Specrity workflows (skipping)"
            else
                generate_cli_single_content > "$full_path"
                log_ok "  Created ${target_path}"
            fi
            ;;

        ide_frontmatter)
            local full_path="${PROJECT_ROOT}/${target_path}"
            local dir
            dir=$(dirname "$full_path")
            mkdir -p "$dir"
            generate_ide_frontmatter_content "$key" > "$full_path"
            log_ok "  Created ${target_path}"
            ;;

        agy_copy)
            deploy_agy_copy
            ;;

        *)
            log_error "  Unknown format type: ${format_type}"
            ;;
    esac
}

# ─── Verify Deployment ───
verify_deployment() {
    log_header "Verification"

    local success=0
    local total=0

    for agent_key in "${SELECTED_AGENTS[@]}"; do
        local entry
        entry=$(get_agent_entry "$agent_key") || continue
        IFS='|' read -r key name target_path format_type <<< "$entry"
        ((total++))

        if [[ "$format_type" == "agy_copy" ]]; then
            local target_dir="${PROJECT_ROOT}/.agents/workflows"
            if [[ -d "$target_dir" ]] && ls "${target_dir}"/*.md &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} ${name}: workflows deployed"
                ((success++))
            else
                echo -e "  ${RED}✗${NC} ${name}: deployment failed"
            fi
        else
            local full_path="${PROJECT_ROOT}/${target_path}"
            if [[ -f "$full_path" ]]; then
                echo -e "  ${GREEN}✓${NC} ${name}: ${target_path}"
                ((success++))
            else
                echo -e "  ${RED}✗${NC} ${name}: ${target_path} not found"
            fi
        fi
    done

    echo ""
    if [[ "$success" -eq "$total" ]]; then
        log_ok "All ${total} agents deployed successfully!"
    else
        log_warn "${success}/${total} agents deployed"
    fi
}

# ─── Main ───
main() {
    echo -e "${BOLD}${CYAN}"
    cat <<'BANNER'
  ____                       _ _         
 / ___| _ __   ___  ___ _ __(_) |_ _   _ 
 \___ \| '_ \ / _ \/ __| '__| | __| | | |
  ___) | |_) |  __/ (__| |  | | |_| |_| |
 |____/| .__/ \___|\___|_|  |_|\__|\__, |
       |_|                         |___/ 
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}v${VERSION} — Specrity Workflow Installer${NC}"
    echo ""

    # Parse arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --help|-h)
                show_help
                ;;
            --list|-l)
                show_list
                ;;
            --all|-a)
                for entry in "${AGENT_REGISTRY[@]}"; do
                    IFS='|' read -r key _ _ _ <<< "$entry"
                    SELECTED_AGENTS+=("$key")
                done
                ;;
            *)
                # Validate provided agent keys
                for arg in "$@"; do
                    if get_agent_entry "$arg" > /dev/null 2>&1; then
                        SELECTED_AGENTS+=("$arg")
                    else
                        log_error "Unknown agent: ${arg}"
                        echo "  Run './install.sh --list' to see supported agents"
                        exit 1
                    fi
                done
                ;;
        esac
    fi

    # Step 1: Find project root
    log_header "Step 1: Detect Project Root"
    find_project_root
    log_ok "Project root: ${PROJECT_ROOT}"

    # Step 2: Check workflows exist
    if [[ ! -d "$WORKFLOWS_DIR" ]] || ! ls "${WORKFLOWS_DIR}"/*.md &>/dev/null; then
        log_error "Workflows directory not found or empty: ${WORKFLOWS_DIR}"
        log_error "Please ensure you're running install.sh from the specrity directory"
        exit 1
    fi
    local workflow_count
    workflow_count=$(find "$WORKFLOWS_DIR" -name "*.md" -type f | wc -l)
    log_ok "Found ${workflow_count} workflow files"

    # Step 3: Select agents (interactive if none specified)
    if [[ ${#SELECTED_AGENTS[@]} -eq 0 ]]; then
        log_header "Step 2: Select AI Agents"
        select_agents_interactive
    fi
    echo ""
    log_info "Selected agents: ${SELECTED_AGENTS[*]}"

    # Step 4: Setup project configuration (.specrity.yml)
    setup_project_config

    # Step 5: Deploy workflows
    log_header "Step 3: Deploy Workflows"
    for agent_key in "${SELECTED_AGENTS[@]}"; do
        local entry
        entry=$(get_agent_entry "$agent_key") || {
            log_error "Agent not found in registry: ${agent_key}"
            continue
        }
        deploy_agent "$entry"
    done

    # Step 5.5: Write version stamp
    local stamp_file="${PROJECT_ROOT}/.specrity-installed"
    cat > "$stamp_file" <<STAMPEOF
# Specrity Version Stamp
# This file is used by workflows to check for updates.
# Do NOT commit this file to git (it's per-user).
version: ${VERSION}
installed_at: $(date -Iseconds)
installed_by: $(whoami)
source: ${SCRIPT_DIR}
agents: ${SELECTED_AGENTS[*]}
STAMPEOF
    log_ok "Version stamp written (v${VERSION})"

    # Add stamp file to .gitignore if not already there
    local gitignore="${PROJECT_ROOT}/.gitignore"
    if [[ -f "$gitignore" ]] && ! grep -q "^\.specrity-installed$" "$gitignore" 2>/dev/null; then
        echo ".specrity-installed" >> "$gitignore"
    fi

    # Step 6: Copy helper scripts and templates
    log_header "Step 4: Deploy Helper Scripts & Templates"
    
    local target_dir="${PROJECT_ROOT}/.specrity"
    mkdir -p "$target_dir"

    local scripts_target="${target_dir}/scripts"
    if [[ ! -d "$scripts_target" ]]; then
        mkdir -p "$scripts_target"
    fi
    if [[ -f "${SCRIPT_DIR}/scripts/create-jira-feature.sh" ]]; then
        cp "${SCRIPT_DIR}/scripts/create-jira-feature.sh" "${scripts_target}/create-jira-feature.sh"
        chmod +x "${scripts_target}/create-jira-feature.sh"
        log_ok "Deployed create-jira-feature.sh"
    fi

    # Copy templates
    if [[ -d "${SCRIPT_DIR}/templates" ]]; then
        mkdir -p "${target_dir}/templates"
        cp -R "${SCRIPT_DIR}/templates/"* "${target_dir}/templates/"
        log_ok "Deployed templates to ${target_dir}/templates/"
    fi

    # Step 7: Verify
    verify_deployment

    # Summary
    echo ""
    log_header "Done! 🎉"
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo "  1. Ensure Atlassian MCP Server is configured in your AI tool"
    echo "  2. Run ${CYAN}/specrity.pm.specify <TICKET_ID>${NC} to start a PRD"
    echo "  3. Run ${CYAN}/specrity.dev.plan <TICKET_ID>${NC} to create an implementation plan"
    echo "  4. Run ${CYAN}/specrity.dev.tasks <TICKET_ID>${NC} to break down tasks"
    echo "  5. Run ${CYAN}/specrity.dev.implement <TICKET_ID>${NC} to start implementing"
    echo ""
}

main "$@"
