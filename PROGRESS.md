# Sahaya Development Progress & Testing Tracker

## ✅ Completed Changes (March 2026)
### Day 6 - Mission Briefing, Accept Flow, and Logistics
1. **Added "What To Bring" Generation via Gemini:**
   - Modified `run_matching()` in `services/telegram-webhook/app.py` to prompt Gemini directly with the specific task dynamics to natively evaluate one-sentence contextual gear instructions for volunteers (`whatToBring`).
   - Mapped logic immediately into standard `match_records` documents saving cleanly to Firestore.
2. **Passed What To Bring into Flutter Engine:**
   - Transferred this generated variable directly from the dynamic match map in `volunteer_home_screen.dart` into `TaskDetailsScreen`.
   - Rendered it structurally below the core Mission Logistics block utilizing a backpack icon dynamically cleanly.
   - Handled text overflows natively by securing layout Columns with `Expanded` widgets to allow long dynamic strings safely wrapped onto new lines.
   - Cleaned up routing architecture parameter schemas to seamlessly process this field without null crashes native to Flutter's constructor initialization routines.
3. ***Note:** FCM Notifications were explicitly skipped completely based on architectural constraints defined by the instruction set.*

### Previous Work
1. **Flutter Models Updated**: 
   - Added `locationWard` (String) and `locationGeoPoint` (GeoPoint) fields to `TaskModel`.
   - Updated `OptionalGeoPointConverter` to cleanly serialize location data.
   - Fixed `MatchRecord` fields strictly expecting `missionBriefing` and `whatToBring` that backend skipped by declaring default optional bindings.
   - Successfully regenerated Freezed and JSON Serializer files.
2. **Backend API Updated (Flask)**: 
   - Modified `services/telegram-webhook/app.py` in the `/generate-tasks` endpoint. The endpoint now extracts the `locationWard` and `locationGeoPoint` from the parent `ProblemCard` and maps it directly onto the new generated tasks before writing them to Firestore.
3. **Volunteer App Feed Logic Added**:
   - Upgraded `volunteer_home_screen.dart` core feed. Replaced hardcoded dummy "Scanning for community needs..." block with native Firestore `StreamBuilder`.
   - Built a dynamic `RecommendedTaskCard` that looks up matching task data and binds it to the interface showing the Match Score, Details, Location Ward, and a "View Task" button.
   - Fixed Firestore crash caused by strict `orderBy` chaining without generating a physical index structurally locally.
   - Built `task_details_screen.dart` to open when tapping View Task. This screen shows the full task metadata, skill requirements, match %, and allows standard volunteers to officially Accept the task to trigger array writes organically in Firebase.
   - Added missing `description` property map directly onto `TaskModel` schema inside Flutter, effectively resolving the undefined getter rendering crash natively.
4. **Seed Data Updated**:  
   - Updated the `seed_service.dart` file to handle mock seeding of these new location parameters.

---

## 🚀 Steps to Test on Your Phone

### Step 1: Re-Upload the Backend Code to Azure
Yes, you **must** redeploy the backend! Since we made changes to `services/telegram-webhook/app.py` (the Flask app that generates tasks), the cloud environment needs the updated Python file to start writing coordinates to Firestore.

Depending on how you deploy to Azure, use your standard deployment method. For example:

**Option A: Using Azure CLI (az webapp up)**
```bash
cd services/telegram-webhook
az webapp up --name <your-azure-app-name>
```

**Option B: Using Git Deployment (if configured)**
```bash
git add services/telegram-webhook/app.py
git commit -m "fix: attach problem coordinates to tasks"
git push azure main
```

### Step 2: Prepare Your Physical Phone
1. **Android**: Enable **Developer Options** and turn on **USB Debugging**. (Go to Settings > About Phone > Tap "Build Number" 7 times, then go back to System > Developer Options > Enable USB Debugging).
2. **iOS**: Connect via cable, open Xcode, select the device, and ensure "Developer Mode" is switched on in your iPhone Settings > Privacy & Security.
3. Plug your phone into your computer.

### Step 3: Run the Flutter App
Open your terminal in VS Code and verify your phone is detected:
```bash
flutter devices
```

Then, execute the app on your physical device:
```bash
flutter run
```
*(If you have multiple devices connected, it will prompt you to choose one, or use `flutter run -d <device-id>`)*

### Step 4: Verify the Behavior
1. Open the Sahaya app on your phone.
2. As an NGO, add/approve a Problem Card to trigger the `/generate-tasks` process to the Azure backend.
3. Go to your **Firebase Firestore UI** in your web browser.
4. Open the `tasks` collection and look at a newly generated task document.
5. Verify that `locationWard` and `locationGeoPoint` are visible on the new task!