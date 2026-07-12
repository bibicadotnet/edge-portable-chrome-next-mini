# [Test Version] Microsoft Edge (Stable, Beta, Dev, Canary) Portable v2

No installation required. Keeps all history, cookies, extensions, and settings even when moved to another device.

- This is a test version, to see if it still experiences random crashes.

# Note:

From July 11, 2026, Microsoft Edge Multi Portable v2 versions will configure the registry in a separate branch `[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge_Portable]`, not sharing the same branch as the regular default Edge version.

Microsoft Edge Multi Portable v2 is officially portable with all separate configurations, without touching the original Edge.

Please delete the old `debloater.reg` and `chrome++.ini` files.
- Run `update.bat` to update to the latest configuration.
- Run `debloat.reg` again to update the registry to the new branch.
- This new feature will be useful when you want to run multiple Edge versions simultaneously (both the original installation and the portable version), or use different Portable versions (v110, v138, v148).

Because the versions support different policies, sharing a single registry branch will cause conflicts or policy errors. By customizing `policy_key=Portable` in the `chrome++.ini` file, each portable version can point to a separate branch with independent settings, resolving this conflict.

### Script features:
 
* Downloads the latest Edge Stable, Beta, Dev, or Canary x64 from [edge_installer_multi](https://github.com/bibicadotnet/edge_installer_multi/releases)
* Integrates [chrome-next-mini](https://github.com/bibicadotnet/chrome-next-mini) for extra features
* Manual update script preserves your settings and configurations

**Download the pre-built [release](https://github.com/bibicadotnet/edge-portable-chrome-next-mini/releases)**, extract, and start using immediately.

---

### Files and Their Purposes

* **chrome++.ini**: configuration file for chrome-next-mini
* **debloater.reg**: removes unnecessary features from Microsoft Edge that I personally don’t use
* **default-apps-multi-profile.bat**: sets the browser as the default application
* **update.bat**: updates to the latest version

---

### DRM

Videos, auto running through DRM will have errors, for example crunchyroll.com has error `SHAK-6007`

No solution yet, because Secure Preferences has been bypassed

### ⚠ Microsoft Defender Antivirus warning

<details>
  <summary>Click to expand</summary>

  Due to the way Microsoft Edge is bypassed to run as a portable app, Microsoft Defender Antivirus may falsely flag it as a trojan.  

  If this happens, allow/whitelist the file and wait for Microsoft Defender’s definitions to update and remove the false positive.  

  <img src="https://img.bibica.net/R09ou3pG.png" alt="R09ou3pG">
</details>
