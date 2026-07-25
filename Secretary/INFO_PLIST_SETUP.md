# Info.plist Configuration for Files App Visibility

## Required for Session 3

To make notebooks and folders visible in the iPad Files app under "On My iPad", you **must** add these two keys to your `Info.plist`:

### Keys to Add:

1. **`UIFileSharingEnabled`** = `YES` (Boolean)
   - Enables "file sharing" which makes the Documents folder visible in Files app

2. **`LSSupportsOpeningDocumentsInPlace`** = `YES` (Boolean)
   - Allows Files app to open documents directly from the app's container
   - Enables editing in place rather than creating copies

### How to Add in Xcode:

1. Select your project in the Project Navigator
2. Select the "Secretary" target
3. Go to the "Info" tab
4. Click the "+" button to add a new key
5. Type `UIFileSharingEnabled` and set type to `Boolean`, value to `YES`
6. Repeat for `LSSupportsOpeningDocumentsInPlace`

### Alternative Method (Direct XML Editing):

If you prefer to edit the Info.plist as source code:

1. Right-click `Info.plist` in Xcode
2. Select "Open As" → "Source Code"
3. Add these lines inside the `<dict>` tag:

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

### Verification:

After adding these keys:
1. Build and run the app
2. Create a notebook or folder from the app
3. Open the Files app on the simulator/device
4. Navigate to "On My iPad" → "Secretary"
5. You should see your notebooks (.notebook bundles) and folders

### Notes:

- The app already stores everything in the Documents directory (see `NotebookBrowser.documentsDirectory`)
- These Info.plist keys are the only remaining requirement for Files app visibility
- Without these keys, the Documents folder remains private and invisible to Files app
