#!/bin/bash
# Test Procedure for PiQwen System
# Run each step and verify before proceeding

echo "========================================"
echo "PiQwen Complete Test Procedure"
echo "========================================"

# Test 1: Raspberry Pi Boots
echo ""
echo "TEST 1: Raspberry Pi Boots"
echo "----------------------------"
echo "Action: Power on Raspberry Pi"
echo "Verify: Green LED blinks, then steady after ~30-60s"
echo "Check: journalctl -u piqwen -f (should show startup)"
echo ""
read -p "Press Enter when Pi has booted..."

# Test 2: Wi-Fi Hotspot Starts
echo ""
echo "TEST 2: Wi-Fi Hotspot Starts"
echo "----------------------------"
echo "Action: Check hostapd and dnsmasq services"
echo "Command: systemctl status hostapd dnsmasq"
echo "Verify: Both services 'active (running)'"
echo ""
read -p "Press Enter to check..."
systemctl status hostapd dnsmasq --no-pager

# Test 3: AI Server Starts
echo ""
echo "TEST 3: AI Server Starts"
echo "------------------------"
echo "Action: Check piqwen service"
echo "Command: systemctl status piqwen"
echo "Verify: Service 'active (running)'"
echo ""
read -p "Press Enter to check..."
systemctl status piqwen --no-pager

# Test 4: /health Works
echo ""
echo "TEST 4: /health Endpoint Works"
echo "------------------------------"
echo "Action: Test health endpoint locally on Pi"
echo "Command: curl http://192.168.4.1:8000/health"
echo "Verify: JSON response with status='ok'"
echo ""
read -p "Press Enter to test..."
curl -s http://192.168.4.1:8000/health | python3 -m json.tool

# Test 5: Apple Watch Connects to Pi Wi-Fi
echo ""
echo "TEST 5: Apple Watch Connects to Pi Wi-Fi"
echo "----------------------------------------"
echo "Action: On Apple Watch, go to Settings > Wi-Fi"
echo "Select: 'PiQwen' network"
echo "Enter: Password set during setup_wifi.sh"
echo "Verify: Watch shows connected to PiQwen"
echo ""
read -p "Press Enter when Watch is connected to PiQwen Wi-Fi..."

# Test 6: Apple Watch Detects Pi
echo ""
echo "TEST 6: Apple Watch Detects Pi"
echo "------------------------------"
echo "Action: Open PiQwen app on Apple Watch"
echo "Navigate: Status tab"
echo "Verify: Shows '● Connected' and Pi info"
echo ""
read -p "Press Enter when verified on Watch..."

# Test 7: User Enters Text
echo ""
echo "TEST 7: User Enters Text"
echo "------------------------"
echo "Action: On Watch, go to Chat tab"
echo "Enter: 'What is 2 + 2?' using scribble or keyboard"
echo "Verify: Text appears in input field"
echo ""
read -p "Press Enter when text entered..."

# Test 8: Text Reaches Pi
echo ""
echo "TEST 8: Text Reaches Pi"
echo "-----------------------"
echo "Action: Press Send on Watch"
echo "Check Pi: journalctl -u piqwen -f"
echo "Verify: Log shows 'Request: POST /chat' and 'Generating response'"
echo ""
read -p "Press Enter after pressing Send..."

# Test 9: Qwen Generates Answer
echo ""
echo "TEST 9: Qwen Generates Answer"
echo "-----------------------------"
echo "Action: Wait for response on Watch (10-30s first time)"
echo "Verify: Answer appears on Watch"
echo ""
read -p "Press Enter when answer received..."

# Test 10: Answer Returns to Watch
echo ""
echo "TEST 10: Answer Returns to Watch"
echo "--------------------------------"
echo "Action: Check Watch display"
echo "Verify: Full answer visible, scrollable if long"
echo ""
read -p "Press Enter when verified..."

# Test 11: Answer Displayed Correctly
echo ""
echo "TEST 11: Answer Displayed Correctly"
echo "-----------------------------------"
echo "Action: Check response format"
echo "Verify: Shows 'You: question' and 'Qwen: answer' with metadata"
echo ""
read -p "Press Enter when verified..."

# Test 12: Chat History Saved
echo ""
echo "TEST 12: Chat History Saved"
echo "---------------------------"
echo "Action: Go to History tab on Watch"
echo "Verify: Conversation appears in list"
echo "Open: Tap conversation to view full history"
echo ""
read -p "Press Enter when verified..."

# Test 13: Connection Failure Handled
echo ""
echo "TEST 13: Connection Failure Handled"
echo "-----------------------------------"
echo "Action: Stop piqwen service: sudo systemctl stop piqwen"
echo "On Watch: Try sending message"
echo "Verify: Shows 'AI server is offline' error, app doesn't crash"
echo "Restart: sudo systemctl start piqwen"
echo ""
read -p "Press Enter to test (will stop service)..."
sudo systemctl stop piqwen
echo "Service stopped. Try sending message on Watch now."
read -p "Press Enter after testing error handling..."
sudo systemctl start piqwen
echo "Service restarted. Wait 10s..."
sleep 10

# Test 14: Raspberry Pi Has No Internet
echo ""
echo "TEST 14: Raspberry Pi Has No Internet"
echo "-------------------------------------"
echo "Action: Disconnect Pi from Ethernet/internet"
echo "Verify: All tests above still pass"
echo ""
read -p "Press Enter after disconnecting internet..."

# Test 15: iPhone Not Present
echo ""
echo "TEST 15: iPhone Not Present"
echo "---------------------------"
echo "Action: Put iPhone in Airplane mode or leave at home"
echo "Verify: Watch still connects to Pi Wi-Fi and works"
echo ""
read -p "Press Enter when iPhone is away..."

# Test 16: System Still Works
echo ""
echo "TEST 16: System Still Works (Fully Offline)"
echo "-------------------------------------------"
echo "Action: Send another question from Watch"
echo "Verify: Complete flow works without internet or iPhone"
echo ""
read -p "Press Enter to test final offline operation..."

echo ""
echo "========================================"
echo "ALL TESTS COMPLETE!"
echo "========================================"
echo ""
echo "If all tests passed, your PiQwen system is ready for use."
echo ""
echo "Summary of what works:"
echo "  ✓ Pi boots and starts services automatically"
echo "  ✓ Wi-Fi hotspot created (PiQwen)"
echo "  ✓ AI server responds on /health and /chat"
echo "  ✓ Apple Watch connects directly to Pi Wi-Fi"
echo "  ✓ Text input and voice input work"
echo "  ✓ Qwen2.5 2B generates answers locally"
echo "  ✓ Responses display on Watch"
echo "  ✓ Chat history saved locally"
echo "  ✓ Error handling works"
echo "  ✓ Fully offline operation confirmed"
echo ""
echo "Enjoy your local AI assistant!"