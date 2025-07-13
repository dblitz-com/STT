# STT Dictate - Claude Development Notes

## Project Overview
**PRODUCTION-READY** open-source voice-to-text system for Mac with **session-based AI editing**. Intercepts the Fn key to toggle dictation, prevents emoji picker, and provides universal text insertion with intelligent post-processing.

## 🎯 Current Status: PRODUCTION READY

### ✅ Core Features Working
- **Perfect Fn Key Detection**: Hardware-level CGEventTap with Sequoia compatibility
- **Session-Based AI Editing**: Processes entire conversation once at end (not word-by-word)
- **Instant Text Insertion**: Clipboard-based paste for immediate output
- **Zero Text During Recording**: Clean UX - text appears only when session ends
- **AI Enhancement**: Grammar correction, filler removal, punctuation via local Ollama
- **Context Awareness**: App-specific tone matching and smart formatting
- **Universal Compatibility**: Works in all macOS applications

### 🚀 Breakthrough: Session-Based AI Architecture

**The Problem We Solved**: Traditional dictation apps process text word-by-word during recording, creating repetitive, choppy output.

**Our Solution**: 
1. **Record Session**: Accumulate entire conversation in buffer
2. **Process Once**: When recording ends, AI processes complete text
3. **Insert Instantly**: Paste final enhanced text via clipboard

**Result**: Smooth, polished text that flows naturally - comparable to Wispr Flow.

## Development Workflow

### Production vs Development
- **Production**: "STT Dictate.app" - stable version for daily use
- **Development**: Use `./build-dev.sh` for testing new features

```bash
# Production build (current perfect version)
./build-app.sh
mv "STT Dictate.app" /Applications/

# Development build (for testing changes)
./build-dev.sh
mv "STT Dictate Dev.app" /Applications/
```

Both versions can run simultaneously with different bundle IDs.

## Quick Start

### Installation
```bash
./setup.sh                    # Install dependencies and models
./build-app.sh                # Build production app
mv "STT Dictate.app" /Applications/
```

### Required Permissions
1. **Accessibility**: System Settings → Privacy & Security → Accessibility
2. **Input Monitoring**: System Settings → Privacy & Security → Input Monitoring  
3. **Microphone**: System Settings → Privacy & Security → Microphone

### Usage
1. Press **Fn** to start recording (🎤 icon appears)
2. Speak your entire message/conversation
3. Press **Fn** again to stop
4. AI processes and inserts enhanced text instantly

## Technical Architecture

### Core Components
- **WhisperKit**: Large-v3-turbo model for speech recognition
- **AVAudioEngine**: Real-time audio capture and processing
- **CGEventTap**: Hardware-level Fn key interception
- **Session Buffer**: Accumulates text during recording
- **AI Pipeline**: Python scripts with Ollama for text enhancement
- **Paste Insertion**: NSPasteboard + CGEvent for instant text output

### Session-Based Processing Flow
```
Fn Press → Start Recording → Audio Buffer → WhisperKit STT → Session Buffer
                ↓
Session Buffer → AI Processing → Enhanced Text → Clipboard → Paste → Done
```

### AI Enhancement Features
- **Filler Removal**: Eliminates "um", "uh", "like", etc.
- **Grammar Correction**: Fixes sentence structure and verb tenses
- **Punctuation**: Adds periods, commas, capitalization
- **Context Matching**: Formal tone for email, casual for chat
- **Command Processing**: Voice commands for text editing

## 🔧 Development Notes

### TCC Cache Bug (Development Only)
During development, macOS Sequoia caches old app signatures. If you see character-by-character typing after rebuilding:

1. **System Settings → Privacy & Security → Accessibility**
2. **Remove** STT Dictate (uncheck + click [-])
3. **Re-add** STT Dictate (click [+], select app)
4. **Enable** the checkbox

This clears the cache and restores instant paste insertion.

### Fn Key Interception Technical Details

**Challenge**: Fn/Globe key operates at hardware level and is consumed by macOS for emoji picker.

**Solution**: Hardware-level CGEventTap with `.cghidEventTap`
- Monitors `CGEventFlags.maskSecondaryFn`
- Consumes Fn events to prevent emoji picker
- Triple fallback: CGEventTap → IOKit HID → NSEvent monitor

**System Modifications** (automatic):
```bash
# Disable Fn emoji picker
defaults write -g AppleFnUsageType -int 0

# Force standard F-keys behavior  
defaults write -g com.apple.keyboard.fnState -bool true
```

## File Structure

### Core Implementation
- `Sources/VoiceDictationService.swift` - Main service with session-based AI
- `Sources/AppDelegate.swift` - Menu bar app and UI
- `ai_editor.py` - Ollama-based text enhancement
- `ai_command_processor.py` - Voice command processing
- `Info.plist` - App permissions and metadata

### Build Scripts
- `build-app.sh` - Production build
- `build-dev.sh` - Development build (runs alongside production)
- `setup.sh` - Dependencies and model installation

### Development Tools
- `test-fn-key.swift` - Test Fn key detection
- `check-permissions.swift` - Verify app permissions
- `definitive-tcc-cache-fix.sh` - TCC cache helper

## Debugging & Troubleshooting

### Common Issues
1. **Fn key not detected**: Check Input Monitoring permission
2. **Character-by-character typing**: TCC cache bug - remove/re-add in Accessibility
3. **No AI enhancement**: Check Ollama installation and Python venv
4. **Text doesn't appear**: Verify both Accessibility and Input Monitoring permissions
5. **App crashes on launch**: Insufficient code signing or wrong location

### Debug Output
Run directly to see logs:
```bash
/Applications/STT\ Dictate.app/Contents/MacOS/STTDictate
```

Look for:
- Event tap creation success
- WhisperKit model loading
- Session buffer accumulation
- AI processing status

## Phase 4 Roadmap (Future Development)

### Hands-Free Features
- **Voice Activity Detection**: Auto-start/stop on speech detection
- **Wake Word Detection**: "Hey STT" activation
- **Continuous Listening**: Background voice processing
- **Double-Tap Activation**: Alternative to Fn key

### Advanced AI Features - Wispr Flow Research

*Detailed research conducted to identify features needed to transform STT Dictate into an advanced, context-aware voice-to-text system that rivals Wispr Flow.*

#### 1. AI-Powered Auto-Edits & Real-Time Formatting

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

#### 2. AI Commands & Voice Editing

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

#### 3. Context-Aware Tone Matching

Wispr Flow adjusts output tone (formal for emails, casual for chats) based on the active app, ensuring natural text.

- **Detection of App Context**: Uses macOS/Windows accessibility APIs to read app metadata (e.g., bundle ID for Mail vs. Slack) or screen context (e.g., via OCR on selected text). This informs the LLM prompt.

- **Tone Adjustment Approach**: Fine-tuned LLM with app-specific prompts (e.g., "Rewrite in professional tone for email"). Unified system: One LLM handles all, conditioned on context tags.

- **Models**: Not app-specific; a single fine-tuned Llama model with conditional prompting.

**Recommended Implementation**:
- **Approach/Models**: Use pyatspi (accessibility) to get app info. Condition your LLM (e.g., Phi-3 mini) with "Tone: formal for [app]" in prompts.
- **Architecture**: On activation, query app → Append to LLM input → Generate toned text.
- **Priorities/Complexity**: Medium complexity (API integration); prioritize for differentiation (2-3 weeks).
- **Open-Source**: Superwhisper uses accessibility for context; VoiceInk has screen awareness.

#### 4. Smart Learning & Personal Dictionary

Wispr Flow builds a user-specific dictionary for jargon, names, and patterns, improving accuracy over time.

- **Building/Maintaining Vocab**: LLM fine-tunes on user data (opt-in), adding words via repeated exposure or manual addition. Uses RLHF (reinforcement learning from human feedback) for adaptation.

- **Learning Proper Nouns/Jargon**: STT + LLM detects outliers (e.g., OOV - out-of-vocabulary words) and adds to a personal embedding layer or dictionary file.

- **Storage/Sync**: Cloud-stored (encrypted, pseudonymized) in user accounts; synced via AWS backend across devices.

**Recommended Implementation**:
- **Approach/Models**: Use WhisperKit's custom vocab feature + local SQLite for dictionary. Fine-tune small LLM on user transcripts (via LoRA for efficiency).
- **Architecture**: Post-transcription, check/add to dict → Sync via iCloud or your server.
- **Priorities/Complexity**: Low for basic dict (1 week); high for learning (fine-tuning, 3-4 weeks). Medium priority.
- **Open-Source**: Biopython or custom via Hugging Face datasets for vocab building.

#### 5. Technical Architecture Questions

- **AI Models**: Fine-tuned Llama 3.1 (open-source) + OpenAI proprietary for enhancements. STT is cloud-based (custom ASR).

- **220 WPM Speeds with AI**: Streaming ASR + fast LLM inference (<250ms/token via TensorRT-LLM). Parallel processing on AWS GPUs; autoscaling for spikes.

- **Latency Optimization**: Chunked streaming (process 1-2s audio segments), edge caching, and dedicated inference deployments. End-to-end <700ms.

- **Privacy Handling**: Cloud-only for AI (no local option); audio not stored, data pseudonymized. Opt-out for training; SOC 2/HIPAA compliant. Transcripts encrypted in transit/storage.

**Recommended**:
- **Architecture**: Hybrid: WhisperKit local STT → Optional cloud LLM for heavy edits. Use Ollama for local inference.
- **Optimization**: Quantize models (8-bit) for speed; batch small chunks.
- **Privacy**: Default to local; offer cloud opt-in.

#### 6. Advanced Activation & Modes

- **Hands-Free Mode (Double-Tap)**: Uses macOS hotkeys or accessibility for tap detection; enables continuous listening.

- **Voice Activity Detection (VAD)**: Silero VAD or similar for starting/stopping based on speech energy thresholds.

- **Noise Filtering/Endpoint Detection**: Pre-processing with noise suppression (e.g., RNNoise) + endpointing in STT to cut silence.

**Recommended**:
- **Approach**: Integrate WebRTC VAD in Python. For double-tap, use pynput library.
- **Architecture**: Background listener thread; filter audio before WhisperKit.
- **Priorities/Complexity**: Low (1 week); high priority for UX.
- **Open-Source**: PyAudio + Silero for VAD.

**Overall Goal Achievement**: Prioritize auto-edits and commands to match Wispr's polish. Start local for privacy edge over their cloud model. Use Superwhisper/VoiceInk as blueprints for quick prototypes.

## Commit History: Key Milestones

- `a232ba2` - **✨ PERFECT**: Session-based AI with instant paste insertion
- `8838552` - **🎉 TRUE SESSION-BASED AI**: Fixed text appearing during recording  
- `2fb9ad7` - **🔧 CRITICAL FIX**: Session replacement bug resolution
- `9dcd0b0` - **🎉 STABLE**: Complete STT Dictate with core features

## Architecture Inspiration: Wispr Flow Analysis

Our session-based approach was inspired by analyzing Wispr Flow's architecture:

### Key Insights Implemented
1. **End-to-End Processing**: Process complete conversations, not fragments
2. **Local-First Privacy**: Keep audio and processing on-device when possible
3. **Instant Output**: Use system clipboard for immediate text insertion
4. **Context Awareness**: Adapt output based on target application
5. **Polish Over Speed**: Better to wait 1-2 seconds for perfect text than get choppy real-time output

### Technical Approaches Adopted
- **Session Buffering**: Accumulate entire conversation before processing
- **Paste-Based Insertion**: Fastest method for large text blocks
- **Python AI Pipeline**: Flexible, easy-to-modify text enhancement
- **Hardware Event Interception**: Reliable Fn key capture
- **Dual App Architecture**: Separate development/production environments

---

**Status**: Production-ready with perfect session-based AI editing. Daily driver quality achieved.