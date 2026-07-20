# ============================================================================
#  Edge Debloater GUI - For Portable Microsoft Edge
#  Applies Edge group policies via the registry with a checkbox UI.
#  Dynamically detects registry path using policy_key in chrome++.ini
# ============================================================================

#region Elevation -------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $args
    exit
}
#endregion

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- Parse chrome++.ini to read policy_key ----------------------------------
$script:PolicyKey = ""
$iniPath = Join-Path $PSScriptRoot "chrome++.ini"
if (Test-Path $iniPath) {
    try {
        $lines = Get-Content $iniPath -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '^\s*policy_key\s*=\s*(.+)$') {
                $script:PolicyKey = $Matches[1].Trim()
                break
            }
        }
    } catch {}
}

# Determine target registry path
$script:BaseRegPath = "HKCU:\SOFTWARE\Policies\Microsoft"
$script:SubKeyName = if ($script:PolicyKey) { "Edge_$($script:PolicyKey)" } else { "Edge" }
$script:EdgePolicyPath = Join-Path $script:BaseRegPath $script:SubKeyName

# ---- Policy definitions mapping debloater.reg -------------------------------
$script:Policies = [ordered]@{
    'Accessibility' = @(
        @{Name='AccessibilityImageLabelsEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable image labels description service.'},
        @{Name='LiveCaptionsAllowed';                  Type='DWORD';  ApplyValue=0; Description='Disable Live captions.'},
        @{Name='ReadAloudEnabled';                     Type='DWORD';  ApplyValue=0; Description='Disable the Read Aloud feature.'}
    )
    'Content settings' = @(
        @{Name='BlockThirdPartyCookies';               Type='DWORD';  ApplyValue=1; Description='Block third-party cookies.'},
        @{Name='DefaultIdleDetectionSetting';          Type='DWORD';  ApplyValue=2; Description='Block sites from detecting idle status.'},
        @{Name='ShowPDFDefaultRecommendationsEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable default PDF recommendations.'},
        @{Name='SpotlightExperiencesAndRecommendationsEnabled';Type='DWORD'; ApplyValue=0; Description='Disable Spotlight and custom wallpapers.'},
        @{Name='AdsTransparencyEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable ads transparency feature for tracking prevention.'},
        @{Name='ConfigureDoNotTrack';                  Type='DWORD';  ApplyValue=1; Description='Send Do Not Track requests to websites.'},
        @{Name='RelatedWebsiteSetsEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable Related Website Sets (prevents related sites seeing your activity).'}
    )
    'Copilot' = @(
        @{Name='ComposeInlineEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable writing assistant Rewrite/Compose.'},
        @{Name='AllowBrowsingWithCopilot';             Type='DWORD';  ApplyValue=0; Description='Disable invoking Copilot for page queries.'},
        @{Name='Microsoft365CopilotChatIconEnabled';   Type='DWORD';  ApplyValue=0; Description='Hide the M365 Copilot Chat icon.'},
        @{Name='CopilotPageContextEnabled';            Type='DWORD';  ApplyValue=0; Description='Block Copilot side pane accessing page content.'},
        @{Name='EdgeEntraCopilotPageContext';          Type='DWORD';  ApplyValue=0; Description='Block Entra Copilot accessing page context.'},
        @{Name='CopilotMode';                          Type='DWORD';  ApplyValue=0; Description='Disable Copilot mode entirely.'},
        @{Name='CopilotMultitabEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable Copilot multitab context features.'},
        @{Name='CopilotNewTabPageEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Copilot features on NTP.'},
        @{Name='CopilotPageContext';                   Type='DWORD';  ApplyValue=0; Description='Broadly block Copilot page context.'},
        @{Name='EdgeEntraCopilotPageContextIncludesHistory';Type='DWORD'; ApplyValue=0; Description='Exclude history from Entra Copilot context.'},
        @{Name='M365LinksAutoOpenCopilotEnabled';      Type='DWORD';  ApplyValue=0; Description='Do not auto-open Copilot for M365 links.'},
        @{Name='ShareBrowsingHistoryWithCopilotSearchAllowed';Type='DWORD'; ApplyValue=0; Description='Do not share browsing history with Copilot.'},
        @{Name='CopilotAddressBarSuggestionsEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable Copilot address bar suggestions.'}
    )
    'Diagnostic Data' = @(
        @{Name='DiagnosticData';                       Type='DWORD';  ApplyValue=0; Description='Disable required/optional diagnostic data to MS.'},
        @{Name='UrlDiagnosticDataEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable sending page URLs to Microsoft.'},
        @{Name='Edge3PSerpTelemetryEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable third-party search engine telemetry.'},
        @{Name='PersonalizationReportingEnabled';      Type='DWORD';  ApplyValue=0; Description='Disable sending browsing history to personalize recommendations.'}
    )
    'Extensions' = @(
        @{Name='ExtensionManifestV2Availability';      Type='DWORD';  ApplyValue=2; Description='Allow Manifest V2 extensions.'}
    )
    'Generative AI' = @(
        @{Name='BuiltInAIAPIsEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable built-in client AI APIs for web pages.'},
        @{Name='EdgeHistoryAISearchEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable AI search in history.'},
        @{Name='AIGenThemesEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable generating themes using DALL-E.'},
        @{Name='GenAILocalFoundationalModelSettings';  Type='DWORD';  ApplyValue=1; Description='Do not download local foundational GenAI model.'}
    )
    'Identity and sign-in' = @(
        @{Name='GuidedSwitchEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable profile switching prompts for personal/work links.'},
        @{Name='ProactiveAuthWorkflowEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable proactive auth with MSN/Bing/Copilot.'},
        @{Name='SeamlessWebToBrowserSignInEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable seamless web-to-browser sign-in.'},
        @{Name='ImplicitSignInEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Implicit Sign-In.'},
        @{Name='AADWebSiteSSOUsingThisProfileEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable AAD Web site SSO.'},
        @{Name='AADWebSSOAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable AAD Web SSO.'},
        @{Name='MSAWebSiteSSOUsingThisProfileAllowed'; Type='DWORD';  ApplyValue=0; Description='Disable MSA Web site SSO.'},
        @{Name='ConfigureOnPremisesAccountAutoSignIn'; Type='DWORD';  ApplyValue=0; Description='Disable Azure AD auto sign-in.'}
    )
    'Microsoft Office' = @(
        @{Name='QuickViewOfficeFilesEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable quick view Office files on the web.'},
        @{Name='ShowOfficeShortcutInFavoritesBar';     Type='DWORD';  ApplyValue=0; Description='Disable showing Office shortcut in Favorites bar.'}
    )
    'Network settings' = @(
        @{Name='NetworkPredictionOptions';             Type='DWORD';  ApplyValue=2; Description='Never predict network actions/prefetch.'},
        @{Name='BuiltInDnsClientEnabled';              Type='DWORD';  ApplyValue=0; Description='Disable the built-in DNS client.'}
    )
    'Password manager and protection' = @(
        @{Name='PasswordGeneratorEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Password Generator.'},
        @{Name='PasswordManagerEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable built-in password manager.'},
        @{Name='PasswordMonitorAllowed';               Type='DWORD';  ApplyValue=0; Description='Disable compromised password monitor.'},
        @{Name='PasswordProtectionWarningTrigger';     Type='DWORD';  ApplyValue=0; Description='Disable password protection warnings.'},
        @{Name='PasswordDismissCompromisedAlertEnabled';Type='DWORD';  ApplyValue=0; Description='Disable dismissing password warnings.'}
    )
    'Performance' = @(
        @{Name='BackgroundModeEnabled';                Type='DWORD';  ApplyValue=0; Description='Do not run background apps when Edge closes.'},
        @{Name='StartupBoostEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable Startup Boost.'},
        @{Name='EfficiencyModeEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Efficiency Mode.'},
        @{Name='ExtensionsPerformanceDetectorEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable extension performance detector.'},
        @{Name='PerformanceDetectorEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable tab performance detector.'},
        @{Name='ClearCachedImagesAndFilesOnExit';      Type='DWORD';  ApplyValue=1; Description='Clear cached images and files when Edge exits.'},
        @{Name='HardwareAccelerationModeEnabled';      Type='DWORD';  ApplyValue=1; Description='Use hardware acceleration when available.'},
        @{Name='HighEfficiencyModeEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable High Efficiency Mode.'},
        @{Name='TabServicesEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable the tab organization service.'}
    )
    'Startup & New Tab' = @(
        @{Name='ShowHomeButton';                       Type='DWORD';  ApplyValue=0; Description='Hide the Home button on toolbar.'},
        @{Name='NewTabPageContentEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Enterprise NTP content.'},
        @{Name='NewTabPageAppLauncherEnabled';         Type='DWORD';  ApplyValue=0; Description='Hide App Launcher on NTP.'},
        @{Name='NewTabPageBingChatEnabled';            Type='DWORD';  ApplyValue=0; Description='Hide Bing Chat on NTP.'},
        @{Name='NewTabPageQuickLinksEnabled';          Type='DWORD';  ApplyValue=0; Description='Hide Quick Links on NTP.'},
        @{Name='AutoImportAtFirstRun';                 Type='DWORD';  ApplyValue=4; Description='Disable automatic import of browser data and settings at first run.'},
        @{Name='HideFirstRunExperience';               Type='DWORD';  ApplyValue=1; Description='Hide the First-run experience and splash screen.'},
        @{Name='ImportBrowserSettings';                Type='DWORD';  ApplyValue=0; Description='Disable importing browser settings from another browser.'},
        @{Name='ImportOnEachLaunch';                   Type='DWORD';  ApplyValue=0; Description='Disable prompt to import browsing data on each launch.'},
        @{Name='NewTabPageSearchBox';                  Type='STRING'; ApplyValue='redirect'; Description='Redirect the new tab page search box to use the Address bar.'}
    )
    'Additional' = @(
        @{Name='SplitScreenEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable the split screen feature.'},
        @{Name='ShowMicrosoftRewards';                 Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Rewards experience.'},
        @{Name='EdgeWalletCheckoutEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable Edge Wallet checkout.'},
        @{Name='EdgeWalletEtreeEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable E-Tree in Edge Wallet.'},
        @{Name='WalletDonationEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable donations via Edge Wallet.'},
        @{Name='AllowGamesMenu';                       Type='DWORD';  ApplyValue=0; Description='Disable Games menu.'},
        @{Name='EdgeEDropEnabled';                     Type='DWORD';  ApplyValue=0; Description='Disable the file-sharing Drop feature.'},
        @{Name='InAppSupportEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable contact support options in-app.'},
        @{Name='QRCodeGeneratorEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the QR Code generator.'},
        @{Name='ShowDownloadsToolbarButton';           Type='DWORD';  ApplyValue=1; Description='Always show the Downloads button on the toolbar.'},
        @{Name='RemoteDebuggingAllowed';               Type='DWORD';  ApplyValue=0; Description='Disable remote debugging.'},
        @{Name='VisualSearchEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable visual search on images.'},
        @{Name='UploadFromPhoneEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the upload from mobile feature.'},
        @{Name='AskBeforeCloseEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable confirmation dialog before closing a window with multiple tabs.'},
        @{Name='PinningWizardAllowed';                 Type='DWORD';  ApplyValue=0; Description='Disable the Pin to taskbar wizard.'},
        @{Name='SharedLinksEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable shared links.'},
        @{Name='ConfigureShare';                       Type='DWORD';  ApplyValue=0; Description='Disable Share experience with other apps.'},
        @{Name='DefaultBrowserSettingsCampaignEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable default browser prompts campaign.'},
        @{Name='LocalBrowserDataShareEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable Windows search indexing Edge local data.'},
        @{Name='MicrosoftEdgeInsiderPromotionEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable Insider channels promotion.'},
        @{Name='EdgeAssetDeliveryServiceEnabled';      Type='DWORD';  ApplyValue=0; Description='Disable Asset Delivery Service.'},
        @{Name='UserFeedbackAllowed';                  Type='DWORD';  ApplyValue=0; Description='Disable user feedback feature.'},
        @{Name='DefaultShareAdditionalOSRegionSetting';Type='DWORD';  ApplyValue=2; Description='Never share additional OS region.'},
        @{Name='EdgeShoppingAssistantEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable Edge Shopping Assistant.'},
        @{Name='BrowserNetworkTimeQueriesEnabled';      Type='DWORD';  ApplyValue=0; Description='Disable network time queries.'},
        @{Name='EdgeAdminCenterEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable Edge Admin Center.'},
        @{Name='WebRtcLocalhostIpHandling';            Type='STRING'; ApplyValue='disable_non_proxied_udp'; Description='Disable WebRTC non-proxied UDP (stops IP leak).'},
        @{Name='RoamingProfileSupportEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable roaming profiles support.'},
        @{Name='ShowRecommendationsEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable feature recommendations notifications.'},
        @{Name='TextPredictionEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable text prediction.'},
        @{Name='PromotionalTabsEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable promotional tabs.'},
        @{Name='SpeechRecognitionEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Speech Recognition.'},
        @{Name='AutofillAddressEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable address autofill.'},
        @{Name='AutofillCreditCardEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable credit card autofill.'},
        @{Name='AutofillMembershipsEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable memberships autofill.'},
        @{Name='PaymentMethodQueryEnabled';            Type='DWORD';  ApplyValue=0; Description='Block sites from checking saved payments.'},
        @{Name='EdgeAutofillMlEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Machine Learning for autofill forms.'},
        @{Name='AlternateErrorPagesEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable alternate HTTP error suggest pages.'},
        @{Name='ResolveNavigationErrorsUseWebService'; Type='DWORD';  ApplyValue=0; Description='Disable web service connection probing.'},
        @{Name='SearchForImageEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable context menu Image Search.'},
        @{Name='SearchFiltersEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable suggestions search filters.'},
        @{Name='SearchbarAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable search bar desktop widget.'},
        @{Name='SearchbarIsEnabledOnStartup';          Type='DWORD';  ApplyValue=0; Description='Disable search widget on startup.'},
        @{Name='WebWidgetAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable Web Widget entirely.'},
        @{Name='EdgeWorkspacesEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Edge Workspaces.'},
        @{Name='ApplicationGuardFavoritesSyncEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable sync of favorites to App Guard.'},
        @{Name='ApplicationGuardTrafficIdentificationEnabled';Type='DWORD'; ApplyValue=0; Description='Disable outbound App Guard traffic headers.'},
        @{Name='WhatsNewPageForEntraProfilesEnabled';   Type='DWORD';  ApplyValue=0; Description='Disable "What`s New" page for Entra profiles.'},
        @{Name='QuickSearchShowMiniMenu';              Type='DWORD';  ApplyValue=0; Description='Disable quick search mini menu.'},
        @{Name='MicrosoftEditorSynonymsEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Editor synonyms.'},
        @{Name='MicrosoftEditorProofingEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Editor proofing.'},
        @{Name='SpellcheckEnabled';                    Type='DWORD';  ApplyValue=0; Description='Disable spellcheck.'},
        @{Name='DefaultBrowserSettingEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable default browser check on startup.'},
        @{Name='EdgeManagementEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Edge management service.'},
        @{Name='ApplicationBoundEncryptionEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable app-bound local data encryption.'},
        @{Name='ConfigureOnlineTextToSpeech';          Type='DWORD';  ApplyValue=0; Description='Disable Online Text-to-Speech voices.'},
        @{Name='MAMEnabled';                           Type='DWORD';  ApplyValue=0; Description='Disable Intune MAM policy retrieval.'},
        @{Name='ScarewareBlockerProtectionEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable Scareware blocker.'},
        @{Name='BingAdsSuppression';                   Type='DWORD';  ApplyValue=1; Description='Suppress ads on Bing.com search.'},
        @{Name='AddressBarWorkSearchResultsEnabled';   Type='DWORD';  ApplyValue=0; Description='Disable work suggestions in address bar.'},
        @{Name='AddressBarTrendingSuggestEnabled';     Type='DWORD';  ApplyValue=0; Description='Disable Bing trending suggestions.'},
        @{Name='EdgeCollectionsEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the Collections feature.'},
        @{Name='EnhanceSecurityMode';                  Type='DWORD';  ApplyValue=0; Description='Disable Enhance security mode in Edge.'},
        @{Name='HubsSidebarEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable the Sidebar launcher bar.'},
        @{Name='StandaloneHubsSidebarEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable the standalone Hubs Sidebar feature.'},
        @{Name='SearchInSidebarEnabled';               Type='DWORD';  ApplyValue=2; Description='Disable the search in sidebar feature.'},
        @{Name='PersonalizeTopSitesInCustomizeSidebarEnabled';Type='DWORD'; ApplyValue=0; Description='Disable personalizing top sites in the customize sidebar.'},
        @{Name='PinBrowserEssentialsToolbarButton';    Type='DWORD';  ApplyValue=0; Description='Unpin the Browser Essentials button from the toolbar.'},
        @{Name='ScreenCaptureAllowed';                 Type='DWORD';  ApplyValue=0; Description='Disable screen capture / screenshot capability.'},
        @{Name='DisableScreenshots';                   Type='DWORD';  ApplyValue=0; Description='Disable the Screenshot (formerly web capture) feature.'},
        @{Name='WebCaptureEnabled';                    Type='DWORD';  ApplyValue=0; Description='Disable the Web Capture feature.'},
        @{Name='ShowAcrobatSubscriptionButton';        Type='DWORD';  ApplyValue=0; Description='Disable the Acrobat premium subscription button in PDF viewer.'},
        @{Name='SmartScreenDnsRequestsEnabled';        Type='DWORD';  ApplyValue=0; Description='Disable SmartScreen DNS requests (reduces background network calls).'},
        @{Name='TyposquattingCheckerEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable Edge Website Typo Protection.'}
    )
}

# Define special items that correspond to subkeys or complex string settings
$script:Specials = [ordered]@{
    'Block Default New Tab (URLBlocklist)' = @{
        SubKey = "URLBlocklist"
        Name   = "1"
        Value  = "ntp.msn.com"
        Type   = "String"
        Description = "Blocks default new tab page by adding ntp.msn.com to URLBlocklist."
        Category = "Startup & New Tab"
    }
    'Install Minimal New Tab extension' = @{
        SubKey = "ExtensionInstallForcelist"
        Name   = "1"
        Value  = "khdnagehanbomfdogegmpddmcalmdnbg"
        Type   = "String"
        Description = "Force installs Minimal New Tab plugin (khdnagehanbomfdogegmpddmcalmdnbg)."
        Category = "Extensions"
    }
    'Allow Google Cookies' = @{
        SubKey = "CookiesAllowedForUrls"
        Name   = "1"
        Value  = "[*.]google.com"
        Type   = "String"
        Description = "Allows storing Google cookies to prevent getting signed out."
        Category = "Content settings"
    }
    'Google Web Only (ManagedSearchEngines)' = @{
        Name   = "ManagedSearchEngines"
        Value  = "[{`"is_default`":true,`"keyword`":`"google.com`",`"name`":`"Google`",`"search_url`":`"https://www.google.com/search?q={searchTerms}&udm=14`",`"suggest_url`":`"https://www.google.com/complete/search?output=chrome&q={searchTerms}`"}]"
        Type   = "String"
        Description = "Sets Google Web (no AI) as default Managed Search Engine."
        Category = "Content settings"
    }
}

# Create GUI Windows Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Edge Debloater GUI ($script:SubKeyName)"
$form.Size = New-Object System.Drawing.Size(850, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Colors & Fonts
$bgColor = [System.Drawing.Color]::FromArgb(245, 246, 248)
$panelBgColor = [System.Drawing.Color]::White
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9)
$fontCode = New-Object System.Drawing.Font("Consolas", 8.5)

$form.BackColor = $bgColor

# Shared ToolTip component (hover hints on buttons)
$script:ToolTip = New-Object System.Windows.Forms.ToolTip
$script:ToolTip.AutoPopDelay = 8000
$script:ToolTip.InitialDelay = 300
$script:ToolTip.ReshowDelay = 100
$script:ToolTip.ShowAlways = $true

# Top Banner
$banner = New-Object System.Windows.Forms.Panel
$banner.Size = New-Object System.Drawing.Size(835, 60)
$banner.Location = New-Object System.Drawing.Point(0, 0)
$banner.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$form.Controls.Add($banner)

$bannerLabel = New-Object System.Windows.Forms.Label
$bannerLabel.Text = "Edge Debloater GUI (Portable Management)"
$bannerLabel.Font = $fontTitle
$bannerLabel.ForeColor = [System.Drawing.Color]::White
$bannerLabel.Location = New-Object System.Drawing.Point(15, 10)
$bannerLabel.Size = New-Object System.Drawing.Size(500, 20)
$banner.Controls.Add($bannerLabel)

$subBannerLabel = New-Object System.Windows.Forms.Label
$subBannerLabel.Text = "Target registry key: HKCU\SOFTWARE\Policies\Microsoft\$script:SubKeyName"
$subBannerLabel.Font = $fontNormal
$subBannerLabel.ForeColor = [System.Drawing.Color]::LightGray
$subBannerLabel.Location = New-Object System.Drawing.Point(15, 32)
$subBannerLabel.Size = New-Object System.Drawing.Size(530, 20)
$banner.Controls.Add($subBannerLabel)

# Policy search box + button (find which tab a policy lives in by name/description)
$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(560, 16)
$txtSearch.Size = New-Object System.Drawing.Size(190, 24)
$txtSearch.Font = $fontNormal
$banner.Controls.Add($txtSearch)

$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.Text = "Search"
$btnSearch.Location = New-Object System.Drawing.Point(755, 15)
$btnSearch.Size = New-Object System.Drawing.Size(65, 25)
$btnSearch.Font = $fontNormal
$btnSearch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$script:ToolTip.SetToolTip($btnSearch, "Search all tabs by policy name or description.")
$banner.Controls.Add($btnSearch)

# Tab bar for Categories
# NOTE: A native WinForms TabControl with Multiline=$true stacks overflow rows in
# reverse order (first-added tabs land on the row closest to the content, later
# tabs get pushed to rows above), which looks like the tabs are shuffled. There is
# no supported property to change that. Instead we build our own simple tab bar
# using a FlowLayoutPanel of Buttons (wraps top-to-bottom in insertion order, like
# normal text wrapping) plus a single content host Panel that shows/hides one
# category panel at a time.
# Bottom Y coordinate the tab bar + content area must together fill (log box starts at y=500)
$tabAreaBottom = 490

$tabBar = New-Object System.Windows.Forms.FlowLayoutPanel
$tabBar.Location = New-Object System.Drawing.Point(10, 70)
$tabBar.Width = 815
$tabBar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$tabBar.WrapContents = $true
$tabBar.AutoScroll = $false
$tabBar.BackColor = $bgColor
# Let the panel grow downward to fit however many rows of tabs are actually needed
# (fixing a fixed height here is what silently clipped/hid overflow rows before).
$tabBar.AutoSize = $true
$tabBar.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$tabBar.MaximumSize = New-Object System.Drawing.Size(815, 0)   # 0 = unbounded height
$form.Controls.Add($tabBar)

# Content host is positioned/sized AFTER all tab buttons are added below, once we
# know how tall the tab bar actually ended up (see after the button-creation loops).
$contentHost = New-Object System.Windows.Forms.Panel
$contentHost.Location = New-Object System.Drawing.Point(10, 140)
$contentHost.Size = New-Object System.Drawing.Size(815, 350)
$contentHost.BackColor = $panelBgColor
$contentHost.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($contentHost)

$script:TabPanels = @{}
$script:TabButtons = @{}
$colorTabNormal = [System.Drawing.Color]::FromArgb(228, 230, 235)
$colorTabSelected = [System.Drawing.Color]::White
$colorTabBorder = [System.Drawing.Color]::FromArgb(190, 193, 199)
$fontTabSelected = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

function Select-Tab ($name) {
    Clear-SearchHighlight
    if ($script:ResultsListBox) { $script:ResultsListBox.Visible = $false }
    foreach ($key in $script:TabPanels.Keys) {
        $script:TabPanels[$key].Visible = ($key -eq $name)
    }
    foreach ($key in $script:TabButtons.Keys) {
        $btn = $script:TabButtons[$key]
        if ($key -eq $name) {
            $btn.BackColor = $colorTabSelected
            $btn.Font = $fontTabSelected
        } else {
            $btn.BackColor = $colorTabNormal
            $btn.Font = $fontNormal
        }
    }
}

# Tracks the checkbox currently highlighted from a search jump, so the yellow
# fill can be reverted the moment the user moves on (switches tab / toggles it).
$script:HighlightedCheckbox = $null
$script:HighlightedOrigColor = $null
$script:HighlightHookedControls = @()

function Clear-SearchHighlight {
    if ($null -ne $script:HighlightedCheckbox) {
        $script:HighlightedCheckbox.BackColor = $script:HighlightedOrigColor
        $script:HighlightedCheckbox = $null
        $script:HighlightedOrigColor = $null
    }
}

function New-CategoryButton ($category) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $category
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderColor = $colorTabBorder
    $btn.BackColor = $colorTabNormal
    $btn.Font = $fontNormal
    $btn.AutoSize = $true
    $btn.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $btn.Padding = New-Object System.Windows.Forms.Padding(8, 2, 8, 2)
    $btn.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 4)
    $btn.Height = 26
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_Click({ Select-Tab $category }.GetNewClosure())
    if ($script:Policies.Contains($category)) {
        $count = $script:Policies[$category].Count
        $script:ToolTip.SetToolTip($btn, "$category`n$count setting(s) in this tab.")
    } else {
        $script:ToolTip.SetToolTip($btn, $category)
    }
    return $btn
}

$script:CheckBoxes = @()
$script:SpecialCheckBoxes = @()

# Load checkboxes dynamically based on categories
foreach ($category in $script:Policies.Keys) {
    # Scrollable panel that acts as the "page" for this category
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.AutoScroll = $true
    $panel.BackColor = $panelBgColor
    $panel.Visible = $false
    $contentHost.Controls.Add($panel)
    $script:TabPanels[$category] = $panel
    
    $yPos = 15
    foreach ($policy in $script:Policies[$category]) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = "$($policy.Name) - $($policy.Description)"
        $chk.Size = New-Object System.Drawing.Size(760, 24)
        $chk.Location = New-Object System.Drawing.Point(15, $yPos)
        $chk.Tag = $policy
        $panel.Controls.Add($chk)
        $script:CheckBoxes += $chk
        $yPos += 28
    }
    
    # Render special policies that belong to this category
    foreach ($key in $script:Specials.Keys) {
        $spec = $script:Specials[$key]
        if ($spec.Category -eq $category) {
            $chk = New-Object System.Windows.Forms.CheckBox
            $policyName = if ($spec.SubKey) { $spec.SubKey } else { $spec.Name }
            $chk.Text = "$policyName - $($spec.Description)"
            $chk.Size = New-Object System.Drawing.Size(760, 24)
            $chk.Location = New-Object System.Drawing.Point(15, $yPos)
            $chk.Tag = $key # store key name
            $panel.Controls.Add($chk)
            $script:SpecialCheckBoxes += $chk
            $yPos += 28
        }
    }
    
    $btn = New-CategoryButton $category
    $tabBar.Controls.Add($btn)
    $script:TabButtons[$category] = $btn
}

# Special "page" for overrides/extra policies
$specialsCategoryName = "Advanced Overrides"

$panelSpecials = New-Object System.Windows.Forms.Panel
$panelSpecials.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelSpecials.AutoScroll = $true
$panelSpecials.BackColor = $panelBgColor
$panelSpecials.Visible = $false
$contentHost.Controls.Add($panelSpecials)

# GroupBox for Custom Configurations
$groupCustom = New-Object System.Windows.Forms.GroupBox
$groupCustom.Text = "Policy Customizations (Tracking Prevention, Sleeping Tabs & DoH)"
$groupCustom.Size = New-Object System.Drawing.Size(765, 200)
$groupCustom.Location = New-Object System.Drawing.Point(15, 15)
$panelSpecials.Controls.Add($groupCustom)

# 1. Tracking Prevention
$script:ChkTrackingEnabled = New-Object System.Windows.Forms.CheckBox
$script:ChkTrackingEnabled.Text = "TrackingPrevention - Enable Tracking Prevention"
$script:ChkTrackingEnabled.Size = New-Object System.Drawing.Size(350, 24)
$script:ChkTrackingEnabled.Location = New-Object System.Drawing.Point(15, 25)
$groupCustom.Controls.Add($script:ChkTrackingEnabled)

$script:CmbTracking = New-Object System.Windows.Forms.ComboBox
$script:CmbTracking.Size = New-Object System.Drawing.Size(250, 25)
$script:CmbTracking.Location = New-Object System.Drawing.Point(380, 22)
$script:CmbTracking.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$script:CmbTracking.Items.Add("Balanced (2) - Recommended")
[void]$script:CmbTracking.Items.Add("Basic (1)")
[void]$script:CmbTracking.Items.Add("Strict (3)")
[void]$script:CmbTracking.Items.Add("Off (0)")
$script:CmbTracking.SelectedIndex = 0
$script:CmbTracking.Enabled = $false
$groupCustom.Controls.Add($script:CmbTracking)

$script:ChkTrackingEnabled.Add_CheckedChanged({
    $script:CmbTracking.Enabled = $script:ChkTrackingEnabled.Checked
})

# 2. Sleeping Tabs Timeout
$script:ChkSleepingEnabled = New-Object System.Windows.Forms.CheckBox
$script:ChkSleepingEnabled.Text = "SleepingTabsTimeout - Enable Sleeping Tabs Timeout"
$script:ChkSleepingEnabled.Size = New-Object System.Drawing.Size(350, 24)
$script:ChkSleepingEnabled.Location = New-Object System.Drawing.Point(15, 65)
$groupCustom.Controls.Add($script:ChkSleepingEnabled)

$script:CmbSleepingTimeout = New-Object System.Windows.Forms.ComboBox
$script:CmbSleepingTimeout.Size = New-Object System.Drawing.Size(250, 25)
$script:CmbSleepingTimeout.Location = New-Object System.Drawing.Point(380, 62)
$script:CmbSleepingTimeout.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$script:CmbSleepingTimeout.Items.Add("15 Minutes (900) - Recommended")
[void]$script:CmbSleepingTimeout.Items.Add("30 Seconds (30)")
[void]$script:CmbSleepingTimeout.Items.Add("5 Minutes (300)")
[void]$script:CmbSleepingTimeout.Items.Add("30 Minutes (1800)")
[void]$script:CmbSleepingTimeout.Items.Add("1 Hour (3600)")
[void]$script:CmbSleepingTimeout.Items.Add("2 Hours (7200)")
[void]$script:CmbSleepingTimeout.Items.Add("3 Hours (10800)")
[void]$script:CmbSleepingTimeout.Items.Add("6 Hours (21600)")
[void]$script:CmbSleepingTimeout.Items.Add("12 Hours (43200)")
$script:CmbSleepingTimeout.SelectedIndex = 0
$script:CmbSleepingTimeout.Enabled = $false
$groupCustom.Controls.Add($script:CmbSleepingTimeout)

$script:ChkSleepingEnabled.Add_CheckedChanged({
    $script:CmbSleepingTimeout.Enabled = $script:ChkSleepingEnabled.Checked
})

# 3. DNS-over-HTTPS (DoH)
$script:ChkDohEnabled = New-Object System.Windows.Forms.CheckBox
$script:ChkDohEnabled.Text = "DnsOverHttpsMode - Enable Secure DNS-over-HTTPS (DoH)"
$script:ChkDohEnabled.Size = New-Object System.Drawing.Size(450, 24)
$script:ChkDohEnabled.Location = New-Object System.Drawing.Point(15, 105)
$groupCustom.Controls.Add($script:ChkDohEnabled)

$script:CmbDohTemplate = New-Object System.Windows.Forms.ComboBox
$script:CmbDohTemplate.Size = New-Object System.Drawing.Size(220, 25)
$script:CmbDohTemplate.Location = New-Object System.Drawing.Point(15, 142)
$script:CmbDohTemplate.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
[void]$script:CmbDohTemplate.Items.Add("Cloudflare Gateway ECS")
[void]$script:CmbDohTemplate.Items.Add("doh.bibica.net")
[void]$script:CmbDohTemplate.Items.Add("Google")
[void]$script:CmbDohTemplate.Items.Add("Cloudflare (Standard)")
[void]$script:CmbDohTemplate.Items.Add("NextDNS")
[void]$script:CmbDohTemplate.Items.Add("Custom Template URL...")
$script:CmbDohTemplate.SelectedIndex = 0
$groupCustom.Controls.Add($script:CmbDohTemplate)

$script:TxtDohCustom = New-Object System.Windows.Forms.TextBox
$script:TxtDohCustom.Size = New-Object System.Drawing.Size(495, 25)
$script:TxtDohCustom.Location = New-Object System.Drawing.Point(250, 142)
$groupCustom.Controls.Add($script:TxtDohCustom)

# Doh template mappings
$script:DohTemplates = @{
    "Cloudflare Gateway ECS" = "https://iabucttpma.cloudflare-gateway.com/dns-query{?dns}"
    "doh.bibica.net"             = "https://doh.bibica.net/dns-query{?dns}"
    "Google"                 = "https://dns.google/dns-query{?dns}"
    "Cloudflare (Standard)"  = "https://cloudflare-dns.com/dns-query{?dns}"
    "NextDNS"                = "https://dns.nextdns.io{?dns}"
}

# ComboBox behavior
$script:CmbDohTemplate.Add_SelectedIndexChanged({
    $sel = $script:CmbDohTemplate.SelectedItem.ToString()
    if ($sel -eq "Custom Template URL...") {
        $script:TxtDohCustom.Text = ""
        $script:TxtDohCustom.ReadOnly = $false
        $script:TxtDohCustom.BackColor = [System.Drawing.Color]::White
    } else {
        $script:TxtDohCustom.Text = $script:DohTemplates[$sel]
        $script:TxtDohCustom.ReadOnly = $true
        $script:TxtDohCustom.BackColor = [System.Drawing.Color]::LightGray
    }
})

# Doh enabled/disabled behavior
$script:ChkDohEnabled.Add_CheckedChanged({
    $en = $script:ChkDohEnabled.Checked
    $script:CmbDohTemplate.Enabled = $en
    $script:TxtDohCustom.Enabled = $en
})

# Initialize states
$script:CmbDohTemplate.Enabled = $false
$script:TxtDohCustom.Enabled = $false
$script:TxtDohCustom.Text = $script:DohTemplates["Cloudflare Gateway ECS"]
$script:TxtDohCustom.ReadOnly = $true
$script:TxtDohCustom.BackColor = [System.Drawing.Color]::LightGray

$script:TabPanels[$specialsCategoryName] = $panelSpecials
$btnSpecials = New-CategoryButton $specialsCategoryName
$script:ToolTip.SetToolTip($btnSpecials, "Advanced Overrides`nTracking Prevention, Sleeping Tabs, DoH & search engine customizations.")
$tabBar.Controls.Add($btnSpecials)
$script:TabButtons[$specialsCategoryName] = $btnSpecials

# Now that every tab button has been added, the FlowLayoutPanel has auto-sized to
# its real, final height (however many rows it actually needed). Reposition/resize
# the content host to sit right under it, using up the remaining space down to
# $tabAreaBottom, so no tab row and no content ever gets clipped.
$tabBar.PerformLayout()
$actualTabBarHeight = $tabBar.PreferredSize.Height
$tabBar.Height = $actualTabBarHeight
$tabContentTop = $tabBar.Bottom + 4
$contentHost.Location = New-Object System.Drawing.Point(10, $tabContentTop)
$contentHost.Size = New-Object System.Drawing.Size(815, [Math]::Max(50, ($tabAreaBottom - $tabContentTop)))

# Show the first category by default (matches previous default of first-added TabPage)
$script:FirstCategory = @($script:Policies.Keys)[0]
Select-Tab $script:FirstCategory

# Search results overlay (same bounds as contentHost, shown on top of it during a search)
$script:ResultsListBox = New-Object System.Windows.Forms.ListBox
$script:ResultsListBox.Location = $contentHost.Location
$script:ResultsListBox.Size = $contentHost.Size
$script:ResultsListBox.Font = $fontNormal
$script:ResultsListBox.HorizontalScrollbar = $true
$script:ResultsListBox.Visible = $false
$form.Controls.Add($script:ResultsListBox)
$script:SearchResultsMap = @()

# Walk up a control's parent chain to find which tab/category panel owns it
function Get-CategoryForControl ($ctrl) {
    $p = $ctrl.Parent
    while ($null -ne $p) {
        foreach ($key in $script:TabPanels.Keys) {
            if ($script:TabPanels[$key] -eq $p) { return $key }
        }
        $p = $p.Parent
    }
    return "Unknown"
}

# Jump to a search result: switch tab, scroll it into view, and keep it highlighted
function Jump-ToSearchResult ($index) {
    if ($index -lt 0 -or $index -ge $script:SearchResultsMap.Count) { return }
    $chk = $script:SearchResultsMap[$index]
    if ($null -eq $chk) { return }
    $cat = Get-CategoryForControl $chk
    Select-Tab $cat
    $script:ResultsListBox.Visible = $false

    $scrollPanel = $chk.Parent
    while ($null -ne $scrollPanel -and -not ($scrollPanel -is [System.Windows.Forms.Panel] -and $scrollPanel.AutoScroll)) {
        $scrollPanel = $scrollPanel.Parent
    }
    if ($null -ne $scrollPanel) { $scrollPanel.ScrollControlIntoView($chk) }
    $chk.Focus()

    # Solid, persistent highlight - stays until the user switches tabs, runs a
    # new search jump, or interacts with this exact checkbox.
    $script:HighlightedCheckbox = $chk
    $script:HighlightedOrigColor = $chk.BackColor
    $chk.BackColor = [System.Drawing.Color]::Yellow
    if ($script:HighlightHookedControls -notcontains $chk) {
        $script:HighlightHookedControls += $chk
        $chk.Add_CheckedChanged({
            if ($script:HighlightedCheckbox -eq $chk) { Clear-SearchHighlight }
        }.GetNewClosure())
    }
}

# Run the search: scan every policy checkbox's displayed "Name - Description" text
function Invoke-PolicySearch {
    $query = $txtSearch.Text.Trim()
    $script:ResultsListBox.Items.Clear()
    $script:SearchResultsMap = @()

    if ([string]::IsNullOrWhiteSpace($query)) {
        $script:ResultsListBox.Visible = $false
        return
    }

    $allChecks = @()
    $allChecks += $script:CheckBoxes
    $allChecks += $script:SpecialCheckBoxes
    $allChecks += $script:ChkTrackingEnabled
    $allChecks += $script:ChkSleepingEnabled
    $allChecks += $script:ChkDohEnabled

    foreach ($chk in $allChecks) {
        if ($chk.Text -like "*$query*") {
            $cat = Get-CategoryForControl $chk
            [void]$script:ResultsListBox.Items.Add("[$cat]  $($chk.Text)")
            $script:SearchResultsMap += $chk
        }
    }

    if ($script:ResultsListBox.Items.Count -eq 0) {
        [void]$script:ResultsListBox.Items.Add("No matching policy found for '$query'.")
        $script:SearchResultsMap += $null
    }

    $script:ResultsListBox.Visible = $true
    $script:ResultsListBox.BringToFront()
}

$btnSearch.Add_Click({ Invoke-PolicySearch })
$txtSearch.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $_.SuppressKeyPress = $true
        Invoke-PolicySearch
    } elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $txtSearch.Text = ""
        $script:ResultsListBox.Visible = $false
    }
})
$script:ResultsListBox.Add_DoubleClick({ Jump-ToSearchResult $script:ResultsListBox.SelectedIndex })
$script:ResultsListBox.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        Jump-ToSearchResult $script:ResultsListBox.SelectedIndex
    }
})

# Log box
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(10, 500)
$logBox.Size = New-Object System.Drawing.Size(815, 80)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = $fontCode
$logBox.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$logBox.ForeColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($logBox)

function Write-Log ($message, $type = "INFO") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$timestamp] [$type] $message`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

# ---- Logic functions --------------------------------------------------------

# Helper: Read Registry State
function Load-RegistryState {
    Write-Log "Reading current registry state from $($script:EdgePolicyPath)..."
    
    # Standard policies
    foreach ($chk in $script:CheckBoxes) {
        $policy = $chk.Tag
        $chk.Checked = $false
        try {
            $cur = Get-ItemProperty -Path $script:EdgePolicyPath -Name $policy.Name -ErrorAction SilentlyContinue
            if ($null -ne $cur) {
                $val = $cur.$($policy.Name)
                if ("$val" -eq "$($policy.ApplyValue)") {
                    $chk.Checked = $true
                }
            }
        } catch {}
    }
    
    # Special policies
    foreach ($chk in $script:SpecialCheckBoxes) {
        $keyName = $chk.Tag
        $spec = $script:Specials[$keyName]
        $chk.Checked = $false
        
        $path = $script:EdgePolicyPath
        if ($spec.SubKey) {
            $path = Join-Path $script:EdgePolicyPath $spec.SubKey
        }
        
        try {
            $cur = Get-ItemProperty -Path $path -Name $spec.Name -ErrorAction SilentlyContinue
            if ($null -ne $cur) {
                $val = $cur.$($spec.Name)
                if ("$val" -eq "$($spec.Value)") {
                    # Additional check for secure DoH templates
                    $allMatch = $true
                    if ($spec.ExtraSettings) {
                        foreach ($extra in $spec.ExtraSettings) {
                            $exCur = Get-ItemProperty -Path $path -Name $extra.Name -ErrorAction SilentlyContinue
                            if ($null -eq $exCur -or "$($exCur.$($extra.Name))" -ne "$($extra.Value)") {
                                $allMatch = $false
                            }
                        }
                    }
                    if ($allMatch) {
                        $chk.Checked = $true
                    }
                }
            }
        } catch {}
    }
    # Load Tracking Prevention
    try {
        $tpCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "TrackingPrevention" -ErrorAction SilentlyContinue
        if ($null -ne $tpCur) {
            $script:ChkTrackingEnabled.Checked = $true
            $tpVal = $tpCur.TrackingPrevention
            if ($tpVal -eq 0) { $script:CmbTracking.SelectedItem = "Off (0)" }
            elseif ($tpVal -eq 1) { $script:CmbTracking.SelectedItem = "Basic (1)" }
            elseif ($tpVal -eq 3) { $script:CmbTracking.SelectedItem = "Strict (3)" }
            else { $script:CmbTracking.SelectedItem = "Balanced (2) - Recommended" }
        } else {
            $script:ChkTrackingEnabled.Checked = $false
            $script:CmbTracking.SelectedItem = "Balanced (2) - Recommended"
        }
    } catch {
        $script:ChkTrackingEnabled.Checked = $false
        $script:CmbTracking.SelectedItem = "Balanced (2) - Recommended"
    }

    # Load Sleeping Tabs Timeout
    try {
        $seCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsEnabled" -ErrorAction SilentlyContinue
        $stCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -ErrorAction SilentlyContinue
        if (($null -ne $seCur -and $seCur.SleepingTabsEnabled -eq 1) -or $null -ne $stCur) {
            $script:ChkSleepingEnabled.Checked = $true
            $stVal = if ($null -ne $stCur) { $stCur.SleepingTabsTimeout } else { 900 }
            switch ($stVal) {
                30    { $script:CmbSleepingTimeout.SelectedItem = "30 Seconds (30)" }
                300   { $script:CmbSleepingTimeout.SelectedItem = "5 Minutes (300)" }
                900   { $script:CmbSleepingTimeout.SelectedItem = "15 Minutes (900) - Recommended" }
                1800  { $script:CmbSleepingTimeout.SelectedItem = "30 Minutes (1800)" }
                3600  { $script:CmbSleepingTimeout.SelectedItem = "1 Hour (3600)" }
                7200  { $script:CmbSleepingTimeout.SelectedItem = "2 Hours (7200)" }
                10800 { $script:CmbSleepingTimeout.SelectedItem = "3 Hours (10800)" }
                21600 { $script:CmbSleepingTimeout.SelectedItem = "6 Hours (21600)" }
                43200 { $script:CmbSleepingTimeout.SelectedItem = "12 Hours (43200)" }
                default { $script:CmbSleepingTimeout.SelectedItem = "15 Minutes (900) - Recommended" }
            }
        } else {
            $script:ChkSleepingEnabled.Checked = $false
            $script:CmbSleepingTimeout.SelectedItem = "15 Minutes (900) - Recommended"
        }
    } catch {
        $script:ChkSleepingEnabled.Checked = $false
        $script:CmbSleepingTimeout.SelectedItem = "15 Minutes (900) - Recommended"
    }

    # Load DNS-over-HTTPS (DoH)
    try {
        $dohModeCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
        if ($null -ne $dohModeCur -and $dohModeCur.DnsOverHttpsMode -eq "secure") {
            $script:ChkDohEnabled.Checked = $true
            $dohTemplateCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue
            if ($null -ne $dohTemplateCur) {
                $tmplVal = $dohTemplateCur.DnsOverHttpsTemplates
                $found = $false
                foreach ($key in $script:DohTemplates.Keys) {
                    if ($script:DohTemplates[$key] -eq $tmplVal) {
                        $script:CmbDohTemplate.SelectedItem = $key
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    $script:CmbDohTemplate.SelectedItem = "Custom Template URL..."
                    $script:TxtDohCustom.Text = $tmplVal
                }
            }
        } else {
            $script:ChkDohEnabled.Checked = $false
        }
    } catch {
        $script:ChkDohEnabled.Checked = $false
    }

    Write-Log "Current registry state loaded successfully." "OK"
}

# Helper: Apply policies to registry
function Apply-Policies {
    Write-Log "Saving settings to registry key $($script:EdgePolicyPath)..."
    
    # Make sure registry path exists
    if (-not (Test-Path $script:EdgePolicyPath)) {
        New-Item -Path $script:EdgePolicyPath -Force | Out-Null
    }
    
    $applied = 0
    $cleared = 0
    
    # Standard policies
    foreach ($chk in $script:CheckBoxes) {
        $policy = $chk.Tag
        if ($chk.Checked) {
            try {
                $regType = if ($policy.Type -eq "DWORD") { "DWord" } else { "String" }
                New-ItemProperty -Path $script:EdgePolicyPath -Name $policy.Name -Value $policy.ApplyValue -PropertyType $regType -Force -ErrorAction Stop | Out-Null
                Write-Log "SET $($policy.Name) = $($policy.ApplyValue)" "OK"
                $applied++
            } catch {
                Write-Log "FAILED to set $($policy.Name): $_" "ERR"
            }
        } else {
            try {
                if (Get-ItemProperty -Path $script:EdgePolicyPath -Name $policy.Name -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $script:EdgePolicyPath -Name $policy.Name -Force | Out-Null
                    Write-Log "REMOVED $($policy.Name)" "OK"
                    $cleared++
                }
            } catch {}
        }
    }
    
    # Special policies
    foreach ($chk in $script:SpecialCheckBoxes) {
        $keyName = $chk.Tag
        $spec = $script:Specials[$keyName]
        
        $targetPath = $script:EdgePolicyPath
        if ($spec.SubKey) {
            $targetPath = Join-Path $script:EdgePolicyPath $spec.SubKey
        }
        
        if ($chk.Checked) {
            try {
                if (-not (Test-Path $targetPath)) {
                    New-Item -Path $targetPath -Force | Out-Null
                }
                $regType = if ($spec.Type -eq "DWORD") { "DWord" } else { "String" }
                New-ItemProperty -Path $targetPath -Name $spec.Name -Value $spec.Value -PropertyType $regType -Force -ErrorAction Stop | Out-Null
                
                if ($spec.ExtraSettings) {
                    foreach ($extra in $spec.ExtraSettings) {
                        $exType = if ($extra.Type -eq "DWORD") { "DWord" } else { "String" }
                        New-ItemProperty -Path $targetPath -Name $extra.Name -Value $extra.Value -PropertyType $exType -Force -ErrorAction Stop | Out-Null
                    }
                }
                Write-Log "SET Special override: $keyName" "OK"
                $applied++
            } catch {
                Write-Log "FAILED to set special: $($keyName): $_" "ERR"
            }
        } else {
            try {
                if (Test-Path $targetPath) {
                    # If it's a subkey container with other properties, remove just the properties
                    if ($spec.SubKey) {
                        if (Get-ItemProperty -Path $targetPath -Name $spec.Name -ErrorAction SilentlyContinue) {
                            Remove-ItemProperty -Path $targetPath -Name $spec.Name -Force | Out-Null
                            Write-Log "REMOVED Special override: $keyName" "OK"
                            $cleared++
                        }
                    } else {
                        # Main key property
                        if (Get-ItemProperty -Path $targetPath -Name $spec.Name -ErrorAction SilentlyContinue) {
                            Remove-ItemProperty -Path $targetPath -Name $spec.Name -Force | Out-Null
                            Write-Log "REMOVED Special override: $keyName" "OK"
                            $cleared++
                        }
                        if ($spec.ExtraSettings) {
                            foreach ($extra in $spec.ExtraSettings) {
                                if (Get-ItemProperty -Path $targetPath -Name $extra.Name -ErrorAction SilentlyContinue) {
                                    Remove-ItemProperty -Path $targetPath -Name $extra.Name -Force | Out-Null
                                }
                            }
                        }
                    }
                }
            } catch {}
        }
    }
    
    # Apply Tracking Prevention
    if ($script:ChkTrackingEnabled.Checked) {
        try {
            $tpSel = $script:CmbTracking.SelectedItem.ToString()
            $tpVal = 2
            if ($tpSel -match '\((\d+)\)') { $tpVal = [int]$Matches[1] }
            New-ItemProperty -Path $script:EdgePolicyPath -Name "TrackingPrevention" -Value $tpVal -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Log "SET TrackingPrevention = $tpVal" "OK"
            $applied++
        } catch {
            Write-Log "FAILED to set TrackingPrevention: $_" "ERR"
        }
    } else {
        try {
            if (Get-ItemProperty -Path $script:EdgePolicyPath -Name "TrackingPrevention" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $script:EdgePolicyPath -Name "TrackingPrevention" -Force | Out-Null
                Write-Log "REMOVED TrackingPrevention" "OK"
                $cleared++
            }
        } catch {}
    }

    # Apply Sleeping Tabs Timeout
    if ($script:ChkSleepingEnabled.Checked) {
        try {
            $stSel = $script:CmbSleepingTimeout.SelectedItem.ToString()
            $stVal = 900
            if ($stSel -match '\((\d+)\)') { $stVal = [int]$Matches[1] }
            New-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsEnabled" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -Value $stVal -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Log "SET SleepingTabsEnabled = 1" "OK"
            Write-Log "SET SleepingTabsTimeout = $stVal" "OK"
            $applied += 2
        } catch {
            Write-Log "FAILED to set Sleeping Tabs policies: $_" "ERR"
        }
    } else {
        try {
            if (Get-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsEnabled" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsEnabled" -Force | Out-Null
                Write-Log "REMOVED SleepingTabsEnabled" "OK"
                $cleared++
            }
            if (Get-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -Force | Out-Null
                Write-Log "REMOVED SleepingTabsTimeout" "OK"
                $cleared++
            }
        } catch {}
    }

    # Apply DNS-over-HTTPS
    if ($script:ChkDohEnabled.Checked) {
        try {
            $dohTmpl = $script:TxtDohCustom.Text.Trim()
            if (-not [string]::IsNullOrEmpty($dohTmpl)) {
                New-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsMode" -Value "secure" -PropertyType String -Force -ErrorAction Stop | Out-Null
                New-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsTemplates" -Value $dohTmpl -PropertyType String -Force -ErrorAction Stop | Out-Null
                Write-Log "SET DoH secure template = $dohTmpl" "OK"
                $applied += 2
            } else {
                Write-Log "DoH Template URL is empty, skipped setting DoH." "WARN"
            }
        } catch {
            Write-Log "FAILED to set DNS-over-HTTPS: $_" "ERR"
        }
    } else {
        try {
            if (Get-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsMode" -Force | Out-Null
                $cleared++
            }
            if (Get-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $script:EdgePolicyPath -Name "DnsOverHttpsTemplates" -Force | Out-Null
                $cleared++
            }
            Write-Log "REMOVED DNS-over-HTTPS" "OK"
        } catch {}
    }

    # Check if subkeys are empty, clean them up
    foreach ($spec in $script:Specials.Values) {
        if ($spec.SubKey) {
            $subPath = Join-Path $script:EdgePolicyPath $spec.SubKey
            if (Test-Path $subPath) {
                $propCount = (Get-Item -Path $subPath).Property.Count
                if ($propCount -eq 0) {
                    Remove-Item -Path $subPath -Force -Recurse | Out-Null
                    Write-Log "Cleaned empty subkey: $($spec.SubKey)"
                }
            }
        }
    }
    
    Write-Log "Finished applying settings. Applied: $applied, Cleared: $cleared" "DONE"
    [System.Windows.Forms.MessageBox]::Show("Successfully saved $applied settings. Please restart Edge to apply.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# Helper: Restore to stock
function Full-Restore {
    $ans = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to restore default/stock behavior? This will completely delete the registry key: `n$($script:EdgePolicyPath)", "Confirm Restore", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne "Yes") { return }
    
    Write-Log "Deleting all values and subkeys from $($script:EdgePolicyPath)..."
    try {
        if (Test-Path $script:EdgePolicyPath) {
            # 1. Remove all subkeys first (URLBlocklist, ExtensionInstallForcelist, etc.)
            $subKeys = Get-ChildItem -Path $script:EdgePolicyPath -ErrorAction SilentlyContinue
            foreach ($sk in $subKeys) {
                Remove-Item -Path $sk.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed subkey: $($sk.PSChildName)" "OK"
            }
            # 2. Remove all values from the main key
            $item = Get-Item -Path $script:EdgePolicyPath -ErrorAction SilentlyContinue
            if ($item) {
                foreach ($propName in $item.Property) {
                    Remove-ItemProperty -Path $script:EdgePolicyPath -Name $propName -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed value: $propName" "OK"
                }
            }
            # 3. Try to remove the now-empty key itself (may fail due to Policies permissions, that's OK)
            try {
                Remove-Item -Path $script:EdgePolicyPath -Recurse -Force -ErrorAction Stop
                Write-Log "Removed empty key $($script:EdgePolicyPath)" "OK"
            } catch {
                Write-Log "Key shell remains (empty, harmless): $($script:EdgePolicyPath)" "INFO"
            }
            Write-Log "Full restore completed successfully." "OK"
        } else {
            Write-Log "Registry key does not exist. Nothing to delete." "INFO"
        }
    } catch {
        Write-Log "FAILED during restore: $_" "ERR"
    }
    
    # Refresh UI checkboxes
    foreach ($chk in $script:CheckBoxes) { $chk.Checked = $false }
    foreach ($chk in $script:SpecialCheckBoxes) { $chk.Checked = $false }
    $script:ChkTrackingEnabled.Checked = $false
    $script:CmbTracking.SelectedIndex = 0
    $script:ChkSleepingEnabled.Checked = $false
    $script:CmbSleepingTimeout.SelectedIndex = 0
    $script:ChkDohEnabled.Checked = $false
    $script:CmbDohTemplate.SelectedIndex = 0
    $script:TxtDohCustom.Text = $script:DohTemplates["Cloudflare Gateway ECS"]
    
    [System.Windows.Forms.MessageBox]::Show("Full restore completed. Restart Edge to see stock behavior.", "Restore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# ---- Control panel layout at the bottom -------------------------------------
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Location = New-Object System.Drawing.Point(10, 590)
$bottomPanel.Size = New-Object System.Drawing.Size(815, 45)
$form.Controls.Add($bottomPanel)
# Load Button
$btnLoad = New-Object System.Windows.Forms.Button
$btnLoad.Text = "Load State"
$btnLoad.Size = New-Object System.Drawing.Size(120, 32)
$btnLoad.Location = New-Object System.Drawing.Point(0, 5)
$btnLoad.Font = $fontNormal
$btnLoad.Add_Click({ Load-RegistryState })
$script:ToolTip.SetToolTip($btnLoad, "Reload the current registry state and refresh all checkboxes.")
$bottomPanel.Controls.Add($btnLoad)

# Select All Button
$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Select All"
$btnSelectAll.Size = New-Object System.Drawing.Size(100, 32)
$btnSelectAll.Location = New-Object System.Drawing.Point(130, 5)
$btnSelectAll.Font = $fontNormal
$script:ToolTip.SetToolTip($btnSelectAll, "Check every setting in all tabs.")
$btnSelectAll.Add_Click({
    foreach ($chk in $script:CheckBoxes) { $chk.Checked = $true }
    foreach ($chk in $script:SpecialCheckBoxes) { $chk.Checked = $true }
    $script:ChkTrackingEnabled.Checked = $true
    $script:ChkSleepingEnabled.Checked = $true
    $script:ChkDohEnabled.Checked = $true
    Write-Log "All settings selected."
})
$bottomPanel.Controls.Add($btnSelectAll)

# Deselect All Button
$btnDeselectAll = New-Object System.Windows.Forms.Button
$btnDeselectAll.Text = "Deselect All"
$btnDeselectAll.Size = New-Object System.Drawing.Size(100, 32)
$btnDeselectAll.Location = New-Object System.Drawing.Point(240, 5)
$btnDeselectAll.Font = $fontNormal
$script:ToolTip.SetToolTip($btnDeselectAll, "Uncheck every setting in all tabs.")
$btnDeselectAll.Add_Click({
    foreach ($chk in $script:CheckBoxes) { $chk.Checked = $false }
    foreach ($chk in $script:SpecialCheckBoxes) { $chk.Checked = $false }
    $script:ChkTrackingEnabled.Checked = $false
    $script:ChkSleepingEnabled.Checked = $false
    $script:ChkDohEnabled.Checked = $false
    Write-Log "All settings deselected."
})
$bottomPanel.Controls.Add($btnDeselectAll)

# Apply Button
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply Settings"
$btnApply.Size = New-Object System.Drawing.Size(140, 32)
$btnApply.Location = New-Object System.Drawing.Point(350, 5)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(34, 197, 94)
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$btnApply.Add_Click({ Apply-Policies })
$script:ToolTip.SetToolTip($btnApply, "Write the checked settings to the registry ($script:EdgePolicyPath).")
$bottomPanel.Controls.Add($btnApply)

# Restore Button
$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "Full Restore / Stock"
$btnRestore.Size = New-Object System.Drawing.Size(160, 32)
$btnRestore.Location = New-Object System.Drawing.Point(500, 5)
$btnRestore.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$btnRestore.ForeColor = [System.Drawing.Color]::White
$btnRestore.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$btnRestore.Add_Click({ Full-Restore })
$script:ToolTip.SetToolTip($btnRestore, "Remove all applied policies and restore Edge to stock/default behavior.")
$bottomPanel.Controls.Add($btnRestore)

# Close Button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Size = New-Object System.Drawing.Size(100, 32)
$btnClose.Location = New-Object System.Drawing.Point(715, 5)
$btnClose.Font = $fontNormal
$btnClose.Add_Click({ $form.Close() })
$script:ToolTip.SetToolTip($btnClose, "Close the application without applying further changes.")
$bottomPanel.Controls.Add($btnClose)

# Startup Initialization
$form.Add_Shown({
    Load-RegistryState
})

# Show UI Form
[void]$form.ShowDialog()
