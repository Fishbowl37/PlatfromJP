## GodotGoogleSignIn Plugin - Quick Reference

### 🔧 Configuration (One-Time Setup)

1. **Get Google Web Client ID**:
   - Go to https://console.cloud.google.com/
   - Navigate to: APIs & Services → Credentials
   - Create/Copy your **Web Application** Client ID

2. **Update AuthManager.gd**:
   ```gdscript
   const GOOGLE_WEB_CLIENT_ID = "123456789-abc.apps.googleusercontent.com"
   ```

3. **Enable in Godot**:
   - Project → Project Settings → Plugins → ✅ GodotGoogleSignIn
   - Project → Export → Android → Plugins → ✅ GodotGoogleSignIn

### 📱 Usage in Your Game

#### Link Account Button (What you need)
```gdscript
# In your UI script (MainMenu, Settings, etc.)
func _on_link_account_button_pressed():
    if AuthManager.can_link_account():
        AuthManager.link_with_google()
    else:
        print("Already linked or not authenticated")

# Listen for result
func _ready():
    AuthManager.account_linked.connect(_on_account_linked)
    AuthManager.link_reward_granted.connect(_on_reward_granted)

func _on_account_linked(success: bool):
    if success:
        print("✅ Account linked successfully!")
        # Show success popup
    else:
        print("❌ Account linking failed")
        # Show error message

func _on_reward_granted(diamonds: int):
    print("💎 Received %d diamonds!" % diamonds)
    # Show reward animation
```

#### Check Link Status
```gdscript
# Show/hide link button based on status
func _ready():
    update_link_button()
    AuthManager.account_linked.connect(_on_link_status_changed)

func update_link_button():
    if AuthManager.is_linked():
        link_button.visible = false
        linked_label.text = "✅ Account Linked"
        linked_label.visible = true
    else:
        link_button.visible = true
        link_button.text = "Link Account (+500 💎)"

func _on_link_status_changed(_success: bool):
    update_link_button()
```

### 🎮 Plugin API Reference

#### Signals
```gdscript
# In AuthManager
signal account_linked(success: bool)  # Emitted when linking completes
signal link_reward_granted(diamonds: int)  # Emitted when reward is given
```

#### Methods
```gdscript
AuthManager.link_with_google()     # Start Google Sign-In flow
AuthManager.is_linked()            # Check if account is linked
AuthManager.can_link_account()     # Check if user can link (not linked yet)
AuthManager.should_show_link_button()  # Same as can_link_account()
```

#### Native Plugin API (Advanced)
```gdscript
var plugin = Engine.get_singleton("GodotGoogleSignIn")

plugin.initialize(web_client_id)    # Initialize plugin
plugin.signIn()                     # Start sign-in (auto-select)
plugin.signInWithAccountChooser()   # Show account picker
plugin.signInWithGoogleButton()     # "Sign in with Google" button flow
plugin.signOut()                    # Sign out

# Signals from native plugin
plugin.sign_in_success.connect(func(id_token, email, display_name):
    print("Signed in: ", email)
)
plugin.sign_in_failed.connect(func(error):
    print("Failed: ", error)
)
```

### 📝 Example: Complete Link Button Implementation

```gdscript
# MainMenu.gd or SettingsPanel.gd
extends Control

@onready var link_button = $LinkAccountButton
@onready var status_label = $AccountStatusLabel

func _ready():
    # Connect signals
    AuthManager.account_linked.connect(_on_account_linked)
    AuthManager.link_reward_granted.connect(_on_reward_granted)
    
    # Update UI
    _update_link_ui()

func _update_link_ui():
    if AuthManager.is_linked():
        link_button.visible = false
        status_label.text = "✅ Google Account Linked"
        status_label.modulate = Color.GREEN
    else:
        link_button.visible = true
        link_button.text = "Link Google Account\n(+500 💎 Reward)"
        status_label.text = "❌ Not Linked"
        status_label.modulate = Color.GRAY

func _on_link_account_button_pressed():
    if not AuthManager.can_link_account():
        _show_message("Already linked or not ready")
        return
    
    link_button.disabled = true
    link_button.text = "Signing in..."
    
    AuthManager.link_with_google()

func _on_account_linked(success: bool):
    link_button.disabled = false
    
    if success:
        _show_message("✅ Account linked successfully!")
        _update_link_ui()
    else:
        link_button.text = "Link Google Account\n(+500 💎 Reward)"
        _show_message("❌ Failed to link account. Try again.")

func _on_reward_granted(diamonds: int):
    _show_reward_popup(diamonds)

func _show_message(text: String):
    # Your popup/toast implementation
    print(text)

func _show_reward_popup(amount: int):
    # Show animated popup with diamond reward
    print("💎 You received %d diamonds!" % amount)
```

### ✅ Testing Checklist

- [ ] Java installed (`java -version`)
- [ ] Plugin built (`./build_plugin.sh`)
- [ ] `GodotGoogleSignIn.aar` exists in `android/plugins/`
- [ ] Web Client ID configured in `AuthManager.gd`
- [ ] Plugin enabled in Project Settings
- [ ] Plugin enabled in Android Export preset
- [ ] Package name matches Google Console (`com.fishbowl.platformjp`)
- [ ] SHA-1 fingerprint added to Google Console (for release builds)

### 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "Plugin not initialized" | Check `GOOGLE_WEB_CLIENT_ID` in AuthManager.gd |
| "Plugin not found" | Run `./build_plugin.sh` and enable in Export settings |
| Sign-in immediately fails | Wrong Client ID or not configured in Google Console |
| Sign-in cancelled | User closed the dialog - this is normal |
| No account chooser shown | User may have only one Google account on device |

### 🔐 Security Notes

- **NEVER** commit your `GOOGLE_WEB_CLIENT_ID` to public repositories
- Use environment variables or secure config for production
- The Web Client ID is less sensitive than API keys, but still keep it private
- Each build variant (debug/release) may need different OAuth clients in Google Console

### 📦 Reward System

Default reward: **500 diamonds** (configurable in AuthManager.gd)

```gdscript
# Change reward amount
const LINK_REWARD_DIAMONDS = 500  # Increase/decrease as needed
```

The reward is:
- ✅ Granted only once per user
- ✅ Saved to user data (survives app restarts)
- ✅ Given after successful link
- ✅ Added to `SkinManager.coins`

---

**Need more help? See `PLUGIN_SETUP.md` for full documentation!**

