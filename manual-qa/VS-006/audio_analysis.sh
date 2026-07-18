#!/bin/bash
# VS-006 Audio Analysis Script
# Run from repo root: ./manual-qa/VS-006/audio_analysis.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

OUTPUT_DIR="manual-qa/VS-006"
mkdir -p "$OUTPUT_DIR"

echo "=== VS-006 Audio Analysis Report ===" > "$OUTPUT_DIR/audio_report.txt"
echo "Generated: $(date)" >> "$OUTPUT_DIR/audio_report.txt"
echo "" >> "$OUTPUT_DIR/audio_report.txt"

# Function to analyze audio file
analyze_audio() {
    local file="$1"
    local basename=$(basename "$file")
    
    echo "=== $basename ===" >> "$OUTPUT_DIR/audio_report.txt"
    
    # Duration
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>&1)
    echo "Duration: ${duration}s" >> "$OUTPUT_DIR/audio_report.txt"
    
    # Volume analysis
    local vol_output=$(ffmpeg -i "$file" -af volumedetect -f null - 2>&1)
    local max_vol=$(echo "$vol_output" | sed -n 's/.*max_volume: \([-0-9.]*\) dB.*/\1/p' | tail -1)
    local mean_vol=$(echo "$vol_output" | sed -n 's/.*mean_volume: \([-0-9.]*\) dB.*/\1/p' | tail -1)
    echo "Max Volume: $max_vol" >> "$OUTPUT_DIR/audio_report.txt"
    echo "Mean Volume: $mean_vol" >> "$OUTPUT_DIR/audio_report.txt"
    
    # Silence detection
    local silence_output=$(ffmpeg -i "$file" -af silencedetect=n=-40dB:d=0.1 -f null - 2>&1)
    local silence_lines=$(echo "$silence_output" | grep "silence_" | tail -1)
    if [ -n "$silence_lines" ]; then
        echo "Silence: $silence_lines" >> "$OUTPUT_DIR/audio_report.txt"
    else
        echo "Silence: None detected" >> "$OUTPUT_DIR/audio_report.txt"
    fi
    
    echo "" >> "$OUTPUT_DIR/audio_report.txt"
}

echo "## SFX Analysis" >> "$OUTPUT_DIR/audio_report.txt"
echo "" >> "$OUTPUT_DIR/audio_report.txt"

for sfx in data/audio/sfx/eleven/*.mp3; do
    if [ -f "$sfx" ]; then
        analyze_audio "$sfx"
    fi
done

echo "## Voice Analysis" >> "$OUTPUT_DIR/audio_report.txt"
echo "" >> "$OUTPUT_DIR/audio_report.txt"

for voice in data/audio/voice/*.mp3; do
    if [ -f "$voice" ]; then
        analyze_audio "$voice"
    fi
done

echo "## Music Analysis" >> "$OUTPUT_DIR/audio_report.txt"
echo "" >> "$OUTPUT_DIR/audio_report.txt"

for music in data/audio/music/*.mp3; do
    if [ -f "$music" ]; then
        analyze_audio "$music"
    fi
done

echo "Report generated: $OUTPUT_DIR/audio_report.txt"
