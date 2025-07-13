# STT Dictate - Claude Development Notes

## Project Overview
Open-source voice-to-text system for Mac that intercepts the Fn key to toggle dictation, preventing the emoji picker and providing universal text insertion across all applications.

## Key Requirements
- Intercept Fn/Globe key globally across all macOS applications
- Prevent system emoji picker from appearing when Fn is pressed
- Insert transcribed text into any active application
- Run as background service with minimal UI (menu bar icon)

## 🔧 Development Note: macOS TCC Cache Bug Workaround

### The Development-Only Issue
During development, macOS Sequoia has a TCC (Transparency, Consent, and Control) caching bug that affects frequently rebuilt/self-signed apps. This is **NOT an issue for end users** - only developers rebuilding the app repeatedly.

### The Simple Fix for Developers
When you see character-by-character typing instead of instant text insertion:

1. **System Settings → Privacy & Security → Accessibility**
2. **Remove** STT Dictate (uncheck + click [-])
3. **Re-add** STT Dictate (click [+], select `/Applications/STT Dictate.app`)
4. **Enable** the checkbox

That's it! This clears the TCC cache and restores instant text insertion.

### Why This Happens (Development Only)
- Each rebuild changes the app signature
- macOS caches the old signature's permissions
- The cache persists even after granting new permissions
- **Production apps with stable signatures don't have this issue**

### Automated Helper Script (Optional)
```bash
./definitive-tcc-cache-fix.sh  # Guides you through the manual steps
```

The app will auto-detect this issue and show a notification when it occurs.

## Technical Architecture
- **Core Engine**: WhisperKit with large-v3-turbo model for speech recognition
- **Audio Processing**: AVAudioEngine for real-time capture
- **Event Interception**: CGEventTap for global hotkey detection
- **Text Insertion**: CGEvent keyboard simulation for universal compatibility
- **App Structure**: macOS app bundle with LaunchAgent for auto-start

## Major Challenge: Fn Key Interception

### Problem
The Fn/Globe key operates at a hardware/firmware level and is heavily controlled by macOS system services. Standard event interception methods often fail because:

1. **System Priority**: macOS consumes Fn events for built-in features (emoji, dictation, window management)
2. **Hardware Level**: Fn is processed by keyboard firmware before reaching software
3. **Security Restrictions**: Recent macOS versions (Sonoma/Sequoia) have tightened event tap permissions

### Solutions Attempted

#### 1. NSEvent Global Monitor (Failed)
- **Method**: `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`
- **Issue**: Passive monitoring only, cannot consume/prevent system actions
- **Result**: Emoji picker still appeared

#### 2. CGEventTap with Session Level (Failed)
- **Method**: `CGEvent.tapCreate()` with `.cgSessionEventTap`
- **Issue**: System consumed Fn events before reaching our tap
- **Result**: Callback never triggered

#### 3. CGEventTap with Hardware Level (Current)
- **Method**: `CGEvent.tapCreate()` with `.cghidEventTap`
- **Events**: Monitor `.flagsChanged`, `.keyDown`, `.keyUp`
- **Flag**: Detect `CGEventFlags.maskSecondaryFn`
- **Status**: Enhanced with Sequoia-specific fixes

### Required Permissions (Critical for Sonoma/Sequoia)
1. **Accessibility**: System Settings > Privacy & Security > Accessibility
2. **Input Monitoring**: System Settings > Privacy & Security > Input Monitoring (NEW requirement)

### System Settings Modifications
```bash
# Disable Fn emoji picker
defaults write -g AppleFnUsageType -int 0

# Force standard F-keys behavior
defaults write -g com.apple.keyboard.fnState -bool true
```

### Current Implementation Status - Wispr Flow Approach
- ✅ **App Sandboxing Disabled** - Unrestricted system access like Wispr Flow
- ✅ **Entitlements Applied** - Proper code signing with security entitlements
- ✅ **System Optimizations** - Auto-disables emoji picker and Fn conflicts
- ✅ **Debug Mode** - Listen-only testing to verify event reception
- ✅ **Enhanced CGEventTap** - Hardware-level with Sequoia compatibility
- ✅ **Dual Permission Support** - Accessibility + Input Monitoring
- ✅ **Hidutil Fallback** - Alternative remapping approach if needed
- ❓ **Testing Required** - Both permission types must be granted

### Fallback Solutions (If Current Approach Fails)

#### 1. hidutil Remapping
```bash
# Remap Fn to unused key code, then intercept that
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000065,"HIDKeyboardModifierMappingDst":0x7000000FF}]}'
```

#### 2. IOKit/HID Level Filtering
- Use IOHIDManager for raw HID report filtering
- Intercept at driver level before system processing
- Requires deep low-level programming

#### 3. Integration with Karabiner-Elements
- Study open-source implementation
- Use proven methods for Fn key remapping
- Consider as dependency or port logic

## Build & Installation

### Quick Start
```bash
./setup.sh                        # Install dependencies and download models
./build-app.sh                     # Build macOS app bundle
mv "STT Dictate.app" /Applications/
./install-service.sh               # Install as background service (optional)
```

**Note for Developers:** If you see character-by-character typing after rebuilding, just remove and re-add the app in System Settings → Accessibility (see Development Note above).

### Development Commands
```bash
swift build              # Build for testing
swift run STTDictate     # Run directly (for debugging)
./fix-fn-key.sh         # Fix system Fn key settings
./test-fn-key.swift     # Simulate Fn key presses
```

## Testing & Debugging

### Check Permissions
- Accessibility: Required for event taps
- Input Monitoring: Required for keyboard events in Sonoma+
- Microphone: Required for speech recognition

### Debug Output
The app provides extensive logging for troubleshooting:
- Event tap creation and status
- Permission checks
- System settings verification
- Real-time event detection

### Common Issues
1. **Character-by-character typing (developers)**: Remove and re-add app in Accessibility settings
2. **No events received**: Missing Input Monitoring permission
3. **Emoji still appears**: System settings not properly disabled
4. **App crashes**: Insufficient code signing or wrong location
5. **Text doesn't appear at all**: Check both Accessibility and Input Monitoring permissions

## Future Improvements
- Alternative hotkey options (if Fn proves unreliable)
- Voice activity detection for automatic start/stop
- Custom command processing
- Multi-language support
- Cloud model options

## Related Files
- `Sources/VoiceDictationService.swift` - Core event handling
- `Sources/AppDelegate.swift` - macOS app structure  
- `Info.plist` - Permissions and app metadata
- `setup.sh` - Dependency installation
- `build-app.sh` - App bundle creation
- `install-service.sh` - Background service setup

## 🤖 AI Enhancement Research - Wispr Flow Analysis

*Research conducted to identify features needed to transform STT Dictate from basic dictation into an intelligent, context-aware voice-to-text system that rivals Wispr Flow.*

### 1. AI-Powered Auto-Edits & Real-Time Formatting

Wispr Flow's auto-edits transform raw speech into polished text by removing fillers, correcting grammar, inserting punctuation, and handling formatting like capitalization and lists. This is achieved through a post-transcription AI layer that refines the output in real-time, making it feel seamless.

- **Removal of Filler Words ("um," "like," "uh")**: This is handled via a fine-tuned large language model (LLM) that processes the transcribed text stream. The model identifies and excises common fillers based on contextual patterns learned during fine-tuning. Implementation likely involves pattern matching in the LLM prompt, where the model is instructed to "remove disfluencies like 'um' or 'uh' while preserving meaning." For real-time operation, audio is streamed to cloud-based speech-to-text (STT), transcribed incrementally, and edited in chunks (e.g., every few seconds) to minimize perceived delay.

- **Automatic Grammar Correction and Punctuation Insertion**: The LLM (fine-tuned Llama variants) rewrites the text for grammatical accuracy and adds punctuation based on prosody cues from the STT output (e.g., pauses for commas/periods). This uses natural language understanding to infer sentence boundaries and structure. The model is prompted with rules like "correct grammar, add punctuation, and ensure fluent flow."

- **Capitalization and Sentence Structure Formatting**: Capitalization is applied contextually (e.g., proper nouns, sentence starts) via LLM rules. Sentence structure is reformatted into lists or paragraphs if spoken cues like "bullet point" are detected. The system supports smart formatting for emails, notes, or code, turning verbal rambling into structured output.

- **Pipeline Approach**: It's a transcribe-then-edit pipeline: Raw audio is transcribed via cloud STT (likely proprietary or enhanced Whisper-like model), then passed to a fine-tuned LLM for enhancement. Real-time processing uses streaming ASR (automatic speech recognition) with incremental updates, achieving <700ms end-to-end latency via optimized inference engines like TensorRT-LLM on AWS.

**Recommended Implementation for STT Dictate**:
- **Approach/Models**: Integrate your WhisperKit STT with a local or cloud LLM for post-processing. Use open-source Llama 3.1 (fine-tune on datasets like Common Voice for disfluencies) via libraries like Hugging Face Transformers or llama.cpp for on-device inference. Prompt example: "Refine this transcript: remove fillers, correct grammar, add punctuation [transcript]."
- **Architecture**: Stream audio to WhisperKit → Buffer transcript chunks → Feed to LLM → Insert edited text at cursor. For real-time, use asyncio in Python for parallel processing.
- **Priorities/Complexity**: Start with filler removal (low complexity, regex + LLM). Add grammar/punctuation (medium, requires fine-tuning). High priority for core UX; estimate 2-4 weeks with existing WhisperKit.
- **Open-Source Alternatives**: Superwhisper uses customizable prompts with Whisper + LLM for similar edits; integrate its codebase for inspiration. VoiceInk (open-source) handles stammer correction locally.

### 2. AI Commands & Voice Editing

Wispr Flow supports voice commands for editing existing text, such as "delete last sentence," "make this more formal," or "insert bullet points," allowing hands-free refinement.

- **Implementation of Commands**: Commands are detected via a hybrid system: Keyword spotting (e.g., "command mode" trigger) shifts to a command parser, or the LLM classifies the input as command vs. content. Once detected, the command is executed on the current text buffer (e.g., via regex for deletion or LLM rewrite for tone changes).

- **Command Recognition Architecture**: Likely a two-pass system: STT transcribes → LLM classifies intent (e.g., using fine-tuned models for NLU - natural language understanding). It uses context from the app or selected text to apply edits.

- **Distinguishing Dictation vs. Commands**: Prefix keywords (e.g., "edit:") or mode switching (e.g., hold key longer) separates them. The LLM can also infer based on semantics – if input doesn't fit dictation flow, it's treated as a command.

- **Scope of Operations**: Includes basic edits (delete, insert, replace), formatting (bold, lists), and advanced (tone shift, summarize). Limited to text manipulation; no system-level actions like app switching.

**Recommended Implementation**:
- **Approach/Models**: Add a command mode to your Fn key (e.g., double-press). Use small NLU models like BERT or fine-tuned Llama for intent classification. For execution, use libraries like NLTK for simple ops or LLM for complex (e.g., "rewrite formally").
- **Architecture**: Extend WhisperKit pipeline: If command detected, route to editor module (Python script using pyautogui for cursor ops). Sync with macOS accessibility APIs for text selection.
- **Priorities/Complexity**: Basic commands first (low, 1-2 weeks). Advanced like tone changes (medium, integrate LLM). Medium priority after auto-edits.
- **Open-Source**: MacWhisper's system prompts can be adapted for commands; FUTO Voice Input has basic voice control.

### 3. Context-Aware Tone Matching

Wispr Flow adjusts output tone (formal for emails, casual for chats) based on the active app, ensuring natural text.

- **Detection of App Context**: Uses macOS/Windows accessibility APIs to read app metadata (e.g., bundle ID for Mail vs. Slack) or screen context (e.g., via OCR on selected text). This informs the LLM prompt.

- **Tone Adjustment Approach**: Fine-tuned LLM with app-specific prompts (e.g., "Rewrite in professional tone for email"). Unified system: One LLM handles all, conditioned on context tags.

- **Models**: Not app-specific; a single fine-tuned Llama model with conditional prompting.

**Recommended Implementation**:
- **Approach/Models**: Use pyatspi (accessibility) to get app info. Condition your LLM (e.g., Phi-3 mini) with "Tone: formal for [app]" in prompts.
- **Architecture**: On activation, query app → Append to LLM input → Generate toned text.
- **Priorities/Complexity**: Medium complexity (API integration); prioritize for differentiation (2-3 weeks).
- **Open-Source**: Superwhisper uses accessibility for context; VoiceInk has screen awareness.

### 4. Smart Learning & Personal Dictionary

Wispr Flow builds a user-specific dictionary for jargon, names, and patterns, improving accuracy over time.

- **Building/Maintaining Vocab**: LLM fine-tunes on user data (opt-in), adding words via repeated exposure or manual addition. Uses RLHF (reinforcement learning from human feedback) for adaptation.

- **Learning Proper Nouns/Jargon**: STT + LLM detects outliers (e.g., OOV - out-of-vocabulary words) and adds to a personal embedding layer or dictionary file.

- **Storage/Sync**: Cloud-stored (encrypted, pseudonymized) in user accounts; synced via AWS backend across devices.

**Recommended Implementation**:
- **Approach/Models**: Use WhisperKit's custom vocab feature + local SQLite for dictionary. Fine-tune small LLM on user transcripts (via LoRA for efficiency).
- **Architecture**: Post-transcription, check/add to dict → Sync via iCloud or your server.
- **Priorities/Complexity**: Low for basic dict (1 week); high for learning (fine-tuning, 3-4 weeks). Medium priority.
- **Open-Source**: Biopython or custom via Hugging Face datasets for vocab building.

### 5. Technical Architecture Questions

- **AI Models**: Fine-tuned Llama 3.1 (open-source) + OpenAI proprietary for enhancements. STT is cloud-based (custom ASR).

- **220 WPM Speeds with AI**: Streaming ASR + fast LLM inference (<250ms/token via TensorRT-LLM). Parallel processing on AWS GPUs; autoscaling for spikes.

- **Latency Optimization**: Chunked streaming (process 1-2s audio segments), edge caching, and dedicated inference deployments. End-to-end <700ms.

- **Privacy Handling**: Cloud-only for AI (no local option); audio not stored, data pseudonymized. Opt-out for training; SOC 2/HIPAA compliant. Transcripts encrypted in transit/storage.

**Recommended**:
- **Architecture**: Hybrid: WhisperKit local STT → Optional cloud LLM for heavy edits. Use Ollama for local inference.
- **Optimization**: Quantize models (8-bit) for speed; batch small chunks.
- **Privacy**: Default to local; offer cloud opt-in.

### 6. Advanced Activation & Modes

- **Hands-Free Mode (Double-Tap)**: Uses macOS hotkeys or accessibility for tap detection; enables continuous listening.

- **Voice Activity Detection (VAD)**: Silero VAD or similar for starting/stopping based on speech energy thresholds.

- **Noise Filtering/Endpoint Detection**: Pre-processing with noise suppression (e.g., RNNoise) + endpointing in STT to cut silence.

**Recommended**:
- **Approach**: Integrate WebRTC VAD in Python. For double-tap, use pynput library.
- **Architecture**: Background listener thread; filter audio before WhisperKit.
- **Priorities/Complexity**: Low (1 week); high priority for UX.
- **Open-Source**: PyAudio + Silero for VAD.

**Overall Goal Achievement**: Prioritize auto-edits and commands to match Wispr's polish. Start local for privacy edge over their cloud model. Use Superwhisper/VoiceInk as blueprints for quick prototypes.