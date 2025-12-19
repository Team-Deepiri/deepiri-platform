#!/usr/bin/env python3
"""
Verify ModelKit integration across Helox and Cyrex
Checks imports, registry access, streaming, and logging
"""
import sys
from pathlib import Path

def check_modelkit():
    """Check if modelkit is available and properly configured"""
    print("🔍 Checking deepiri-modelkit...")
    try:
        import deepiri_modelkit
        from deepiri_modelkit import (
            AIModel, ModelInput, ModelOutput, ModelMetadata,
            ModelRegistryClient, StreamingClient,
            ModelReadyEvent, get_logger
        )
        print("✅ ModelKit imports successful")
        print(f"   Version: {deepiri_modelkit.__version__}")
        return True
    except ImportError as e:
        print(f"❌ ModelKit import failed: {e}")
        print("   Fix: pip install -e ./deepiri-modelkit")
        return False

def check_helox_integration():
    """Check if Helox properly imports modelkit"""
    print("\n🔍 Checking Helox integration...")
    helox_files = [
        "diri-helox/mlops/experiment_tracker.py",
        "diri-helox/mlops/lora_training.py",
        "diri-helox/pipelines/training/ml_training_pipeline.py",
    ]
    
    success = True
    for file_path in helox_files:
        if not Path(file_path).exists():
            print(f"⚠️  {file_path} not found")
            continue
        
        with open(file_path) as f:
            content = f.read()
            if "deepiri_modelkit" in content:
                print(f"✅ {file_path} uses modelkit")
            else:
                print(f"⚠️  {file_path} doesn't import modelkit")
                success = False
    
    return success

def check_cyrex_integration():
    """Check if Cyrex properly imports modelkit"""
    print("\n🔍 Checking Cyrex integration...")
    
    # Check if Cyrex files exist and use modelkit
    cyrex_path = Path("diri-cyrex/app")
    if not cyrex_path.exists():
        print("❌ diri-cyrex/app not found")
        return False
    
    # Look for model_loader, registry files
    model_files = list(cyrex_path.glob("**/model*.py"))
    registry_files = list(cyrex_path.glob("**/registry*.py"))
    
    print(f"   Found {len(model_files)} model files")
    print(f"   Found {len(registry_files)} registry files")
    
    # Check if any use modelkit
    uses_modelkit = False
    for file in model_files + registry_files:
        with open(file) as f:
            if "deepiri_modelkit" in f.read():
                print(f"✅ {file.relative_to('diri-cyrex/app')} uses modelkit")
                uses_modelkit = True
    
    if not uses_modelkit:
        print("⚠️  No Cyrex files use modelkit yet")
        print("   TODO: Update model_loader.py and registry files")
    
    return uses_modelkit

def check_logging():
    """Check if services use shared logging"""
    print("\n🔍 Checking shared logging...")
    try:
        from deepiri_modelkit import get_logger, get_error_logger
        logger = get_logger("test")
        logger.info("test_event", status="ok")
        print("✅ Shared logging works")
        return True
    except Exception as e:
        print(f"❌ Logging check failed: {e}")
        return False

def check_registry():
    """Check if model registry client works"""
    print("\n🔍 Checking model registry...")
    try:
        from deepiri_modelkit import ModelRegistryClient
        # Don't actually connect, just check import
        print("✅ Model registry client available")
        return True
    except Exception as e:
        print(f"❌ Registry check failed: {e}")
        return False

def check_streaming():
    """Check if streaming client is available"""
    print("\n🔍 Checking streaming client...")
    try:
        from deepiri_modelkit import StreamingClient, ModelReadyEvent
        print("✅ Streaming client available")
        return True
    except Exception as e:
        print(f"❌ Streaming check failed: {e}")
        return False

def main():
    print("=" * 60)
    print("DEEPIRI MODELKIT INTEGRATION CHECK")
    print("=" * 60)
    
    results = {
        "ModelKit": check_modelkit(),
        "Helox Integration": check_helox_integration(),
        "Cyrex Integration": check_cyrex_integration(),
        "Shared Logging": check_logging(),
        "Model Registry": check_registry(),
        "Streaming": check_streaming(),
    }
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    for check, passed in results.items():
        status = "✅" if passed else "❌"
        print(f"{status} {check}")
    
    all_passed = all(results.values())
    
    if all_passed:
        print("\n🎉 All checks passed! ModelKit is properly integrated.")
        return 0
    else:
        print("\n⚠️  Some checks failed. Review the output above.")
        print("\nQuick fixes:")
        print("  1. pip install -e ./deepiri-modelkit")
        print("  2. Update imports in Cyrex and Helox")
        print("  3. Ensure Redis and MLflow are configured")
        return 1

if __name__ == "__main__":
    sys.exit(main())

