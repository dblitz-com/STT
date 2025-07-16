# PILLAR 2: System Audio Capture (Cheating Daddy-style)

## Overview
Capture ALL audio sources - not just microphone, but system sounds, meeting audio, videos, music, etc.

## What It Does
- Captures system-wide audio output
- Mixes microphone and system audio streams
- Enables understanding of full audio context
- Real-time processing for immediate context

## Current Status: ❌ Not Implemented
- ✅ Microphone capture (WhisperKit)
- ❌ System audio capture
- ❌ Audio stream mixing
- ❌ Real-time audio memory

## Implementation Requirements

### 1. Native macOS System Audio Capture
```swift
// system_audio_capture.swift (TODO)
import AVFoundation
import CoreAudio

class SystemAudioCapture {
    private var audioEngine: AVAudioEngine
    private var systemAudioTap: AVAudioNodeTapBlock?
    
    func startSystemAudioCapture() {
        // Create audio tap on system output
        // Mix with microphone input
        // Stream to Python via XPC
    }
}
```

### 2. Audio Mixing Pipeline
```python
# audio_mixer_service.py (TODO)
class AudioMixerService:
    def mix_audio_streams(self, mic_audio, system_audio):
        """Mix microphone and system audio streams"""
        # Implement audio mixing
        # Handle different sample rates
        # Normalize levels
```

### 3. Real-time Audio Processing
```python
# audio_context_service.py (TODO)
class AudioContextService:
    def process_audio_context(self, audio_chunk):
        """Process audio in real-time"""
        # Transcribe with WhisperKit
        # Separate speakers (diarization)
        # Store in audio memory
```

## What This Enables
- "What did they say in the Zoom meeting?"
- "What was that error sound 5 minutes ago?"
- "Transcribe the video I just watched"
- Understanding full context of user's audio environment

## Technical Approach (from Cheating Daddy)
- Use native macOS Core Audio APIs
- Create system audio tap (like SystemAudioDump)
- Stream audio chunks to Python
- Process in parallel with visual context

## Privacy Considerations
- User consent for system audio capture
- Clear indicators when recording
- Secure storage of audio contexts
- Option to disable/delete audio history