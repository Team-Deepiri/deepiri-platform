#!/bin/bash

ACTION=$1
TEAM=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$ACTION" == "pull" ]; then
    case $TEAM in
        backend)
            bash "$SCRIPT_DIR/backend-team/pull_submodules.sh"
            ;;
        frontend)
            bash "$SCRIPT_DIR/frontend-team/pull_submodules.sh"
            ;;
        ai)
            bash "$SCRIPT_DIR/ai-team/pull_submodules.sh"
            ;;
        infrastructure)
            bash "$SCRIPT_DIR/infrastructure-team/pull_submodules.sh"
            ;;
        qa)
            bash "$SCRIPT_DIR/qa-team/pull_submodules.sh"
            ;;
        ml)
            bash "$SCRIPT_DIR/ml-team/pull_submodules.sh"
            ;;
        platform)
            bash "$SCRIPT_DIR/platform-engineers/pull_submodules.sh"
            ;;
        all)
            bash "$SCRIPT_DIR/all_submodules/pull_submodules.sh"
            ;;
        *)
            echo "Usage: ./submodules.sh pull [backend|frontend|ai|infrastructure|qa|ml|platform|all]"
            ;;
    esac
else
    echo "Usage: ./submodules.sh pull [team]"
fi
