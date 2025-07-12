-- Simple AppleScript to test Fn key alternative
-- This bypasses Input Monitoring requirements

on run
    display notification "STT Active - Press Space to toggle" with title "STT Dictate"
    
    repeat
        -- Wait for user input (simplified approach)
        delay 1
    end repeat
end run