# Microsoft Edge (Stable, Beta, Dev, Canary) Portable v2

No installation required. Keeps all history, cookies, extensions, and settings intact even when moved to another folder or device.

---

## Registry Isolation & Multi-Version Support

Microsoft Edge Multi Portable v2 configures the registry in a separate branch: `[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge_Portable]`. It operates completely independently without sharing policy branches or modifying the original installed Edge settings.

This architecture allows you to run multiple Edge versions simultaneously (such as installed Edge alongside Portable builds, or different Portable releases like v110, v138, v148).

### Update / Migration Instructions:
1. Delete old `debloater.reg` / `debloat.reg` and `chrome++.ini` files.
2. Run `update.bat` to update to the latest configuration files.
3. Run `debloat.reg` to apply registry settings to the new isolated branch.

> **Technical note:** Sharing a single registry branch across different browser versions can cause policy conflicts. By setting `policy_key=Portable` in `chrome++.ini`, each portable build points to its own dedicated registry branch.

---

## Script Features

- **Automated Downloads:** Fetches the latest Edge x64 (Stable, Beta, Dev, or Canary) from [edge_installer_multi](https://github.com/bibicadotnet/edge_installer_multi/releases).
- **Extended Capabilities:** Integrates [chrome-next-mini](https://github.com/bibicadotnet/chrome-next-mini) for extra portability options and features.
- **Data Safety:** Manual update scripts keep your user data, settings, and profiles completely safe during updates.

**Quick Start:** Download the pre-built [release](https://github.com/bibicadotnet/edge-portable-chrome-next-mini/releases), extract, and run directly.

---

## Included Files

| File | Purpose |
| --- | --- |
| `chrome++.ini` | Configuration file for `chrome-next-mini` modules. |
| `debloat.reg` | Applies policy tweaks to remove non-essential Edge features and telemetry. |
| `default-apps-multi-profile.bat` | Script to set the portable browser as the default system browser. |
| `update.bat` | Updates the browser and configuration files to the latest release while retaining user data. |

---

## Known Issues & Limitations

### DRM Playback
Videos protected by DRM (such as Crunchyroll returning error `SHAK-6007`) will experience playback errors. This occurs because Secure Preferences checks are bypassed to achieve full portability.

### ⚠ Microsoft Defender Antivirus Warning

<details>
  <summary>Click to expand details</summary>

  Due to the hooking method used to run Microsoft Edge portably without installation, Microsoft Defender Antivirus or third-party security software may occasionally flag launcher files as false positives.

  If this occurs:
  1. Add the portable folder to your antivirus whitelist/exclusion list.
  2. False positive detections usually resolve automatically after Defender definition updates.

  <img src="https://img.bibica.net/R09ou3pG.png" alt="Antivirus Detection Example">
</details>
