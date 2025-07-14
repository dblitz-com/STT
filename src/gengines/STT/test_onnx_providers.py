#!/usr/bin/env python3
"""
Test openWakeWord with different ONNX execution providers.
"""

import numpy as np
import onnxruntime as ort

def test_onnx_providers():
    """Check available ONNX providers and test model inference."""
    print("🔍 Checking ONNX Runtime configuration...")
    print(f"📊 ONNX Runtime version: {ort.__version__}")
    print(f"📊 Available providers: {ort.get_available_providers()}")
    print(f"📊 Device: {ort.get_device()}")
    
    # Try to load the hey_jarvis model directly with ONNX Runtime
    model_path = "/Users/devin/dblitz/engine/src/gengines/STT/venv_py312/lib/python3.12/site-packages/openwakeword/resources/models/hey_jarvis_v0.1.onnx"
    
    print(f"\n🚀 Loading model directly with ONNX Runtime...")
    try:
        # Create session with explicit provider
        session_options = ort.SessionOptions()
        session_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        
        # Try with CPU provider explicitly
        session = ort.InferenceSession(
            model_path,
            sess_options=session_options,
            providers=['CPUExecutionProvider']
        )
        
        print("✅ Model loaded successfully!")
        
        # Get model info
        print("\n📊 Model inputs:")
        for inp in session.get_inputs():
            print(f"   - {inp.name}: shape={inp.shape}, dtype={inp.type}")
            
        print("\n📊 Model outputs:")
        for out in session.get_outputs():
            print(f"   - {out.name}: shape={out.shape}, dtype={out.type}")
        
        # Create test input based on model requirements
        input_name = session.get_inputs()[0].name
        input_shape = session.get_inputs()[0].shape
        
        # Generate test audio (16000 samples = 1 second at 16kHz)
        test_audio = np.random.randn(16000).astype(np.float32) * 0.1
        
        # Reshape if needed
        if len(input_shape) == 2:
            test_audio = test_audio.reshape(1, -1)
        
        print(f"\n🧪 Running inference with test audio shape: {test_audio.shape}")
        
        # Run inference
        outputs = session.run(None, {input_name: test_audio})
        
        print(f"📊 Raw output: {outputs}")
        print(f"📊 Output shape: {outputs[0].shape if outputs else 'None'}")
        print(f"📊 Output values: {outputs[0] if outputs else 'None'}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_onnx_providers()