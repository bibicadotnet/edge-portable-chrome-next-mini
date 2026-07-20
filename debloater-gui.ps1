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
    'Edge Features' = @(
        @{Name='HideFirstRunExperience';               Type='DWORD';  ApplyValue=1; Description='Disable the First-run welcome experience and splash screen.'},
        @{Name='SearchInSidebarEnabled';               Type='DWORD';  ApplyValue=2; Description='Disable the search in sidebar feature.'},
        @{Name='HubsSidebarEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable the Sidebar launcher bar on the right.'},
        @{Name='ReadAloudEnabled';                     Type='DWORD';  ApplyValue=0; Description='Disable the Read Aloud feature.'},
        @{Name='EdgeCollectionsEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the Collections panel.'},
        @{Name='SplitScreenEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable the split screen feature.'},
        @{Name='WebCaptureEnabled';                    Type='DWORD';  ApplyValue=0; Description='Disable the Web Capture / Screenshot feature.'},
        @{Name='DisableScreenshots';                   Type='DWORD';  ApplyValue=0; Description='Disable screenshot saving capability.'},
        @{Name='ScreenCaptureAllowed';                 Type='DWORD';  ApplyValue=0; Description='Disable screen capturing.'},
        @{Name='GuidedSwitchEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable profile switching prompts for personal/work links.'},
        @{Name='ShowMicrosoftRewards';                 Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Rewards experience.'},
        @{Name='AutoImportAtFirstRun';                 Type='DWORD';  ApplyValue=4; Description='Disable auto-import of browser data at first run.'},
        @{Name='EdgeWorkspacesEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Edge Workspaces.'},
        @{Name='EdgeWalletCheckoutEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable Edge Wallet checkout.'},
        @{Name='EdgeWalletEtreeEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable E-Tree in Edge Wallet.'},
        @{Name='WalletDonationEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable donations via Edge Wallet.'},
        @{Name='AllowGamesMenu';                       Type='DWORD';  ApplyValue=0; Description='Disable Games menu.'},
        @{Name='EdgeEDropEnabled';                     Type='DWORD';  ApplyValue=0; Description='Disable the file-sharing Drop feature.'},
        @{Name='InAppSupportEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable contact support options in-app.'},
        @{Name='QuickViewOfficeFilesEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable quick view Office files on the web.'},
        @{Name='QRCodeGeneratorEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the QR Code generator.'},
        @{Name='ShowDownloadsToolbarButton';           Type='DWORD';  ApplyValue=1; Description='Always show the Downloads button on the toolbar.'},
        @{Name='RemoteDebuggingAllowed';               Type='DWORD';  ApplyValue=0; Description='Disable remote debugging.'},
        @{Name='VisualSearchEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable visual search on images.'},
        @{Name='UploadFromPhoneEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable the upload from mobile feature.'},
        @{Name='AskBeforeCloseEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable confirmation dialog before closing a window with multiple tabs.'},
        @{Name='StandaloneHubsSidebarEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable the standalone Hubs Sidebar.'},
        @{Name='ShowOfficeShortcutInFavoritesBar';     Type='DWORD';  ApplyValue=0; Description='Disable showing Office shortcut in Favorites bar.'},
        @{Name='PinBrowserEssentialsToolbarButton';    Type='DWORD';  ApplyValue=0; Description='Unpin the Browser Essentials button from the toolbar.'},
        @{Name='TabServicesEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable tab organization service.'},
        @{Name='ShowAcrobatSubscriptionButton';        Type='DWORD';  ApplyValue=0; Description='Disable Adobe Acrobat subscription button in PDF viewer.'},
        @{Name='ShowHomeButton';                       Type='DWORD';  ApplyValue=0; Description='Hide the Home button on toolbar.'},
        @{Name='PinningWizardAllowed';                 Type='DWORD';  ApplyValue=0; Description='Disable the Pin to taskbar wizard.'},
        @{Name='ImportOnEachLaunch';                   Type='DWORD';  ApplyValue=0; Description='Disable prompt to import browsing data on each launch.'},
        @{Name='ShowPDFDefaultRecommendationsEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable default PDF recommendations.'},
        @{Name='LiveCaptionsAllowed';                  Type='DWORD';  ApplyValue=0; Description='Disable Live captions.'},
        @{Name='SharedLinksEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable shared links.'}
    )
    'Privacy & Telemetry' = @(
        @{Name='DiagnosticData';                       Type='DWORD';  ApplyValue=0; Description='Disable required/optional diagnostic data to MS.'},
        @{Name='UrlDiagnosticDataEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable sending page URLs to Microsoft.'},
        @{Name='PersonalizationReportingEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable personalization reports (browsing history).'},
        @{Name='AccessibilityImageLabelsEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable image labels description service.'},
        @{Name='ConfigureShare';                       Type='DWORD';  ApplyValue=0; Description='Disable Share experience with other apps.'},
        @{Name='DefaultBrowserSettingsCampaignEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable default browser prompts campaign.'},
        @{Name='Edge3PSerpTelemetryEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable third-party search engine telemetry.'},
        @{Name='LocalBrowserDataShareEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable Windows search indexing Edge local data.'},
        @{Name='MicrosoftEdgeInsiderPromotionEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable Insider channels promotion.'},
        @{Name='RelatedWebsiteSetsEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable Related Website Sets (privacy isolation).'},
        @{Name='AdsTransparencyEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable ads transparency settings.'},
        @{Name='EdgeAssetDeliveryServiceEnabled';      Type='DWORD';  ApplyValue=0; Description='Disable Asset Delivery Service.'},
        @{Name='UserFeedbackAllowed';                  Type='DWORD';  ApplyValue=0; Description='Disable user feedback feature.'},
        @{Name='DefaultShareAdditionalOSRegionSetting';Type='DWORD';  ApplyValue=2; Description='Never share additional OS region.'},
        @{Name='EdgeShoppingAssistantEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable Edge Shopping Assistant.'},
        @{Name='BlockThirdPartyCookies';               Type='DWORD';  ApplyValue=1; Description='Block third-party cookies.'},
        @{Name='ConfigureDoNotTrack';                  Type='DWORD';  ApplyValue=1; Description='Send Do Not Track requests.'},
        @{Name='SmartScreenDnsRequestsEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable SmartScreen DNS requests.'},
        @{Name='BrowserNetworkTimeQueriesEnabled';      Type='DWORD';  ApplyValue=0; Description='Disable network time queries.'},
        @{Name='ClearCachedImagesAndFilesOnExit';      Type='DWORD';  ApplyValue=1; Description='Clear cached images and files on exit.'},
        @{Name='DefaultIdleDetectionSetting';          Type='DWORD';  ApplyValue=2; Description='Block sites from detecting idle status.'},
        @{Name='EdgeAdminCenterEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable Edge Admin Center.'},
        @{Name='WebRtcLocalhostIpHandling';            Type='STRING'; ApplyValue='disable_non_proxied_udp'; Description='Disable WebRTC non-proxied UDP (stops IP leak).'},
        @{Name='PersonalizeTopSitesInCustomizeSidebarEnabled';Type='DWORD'; ApplyValue=0; Description='Disable personalizing top sites in customize sidebar.'},
        @{Name='RoamingProfileSupportEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable roaming profiles support.'},
        @{Name='ShowRecommendationsEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable feature recommendations notifications.'},
        @{Name='TextPredictionEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable text prediction.'},
        @{Name='TyposquattingCheckerEnabled';          Type='DWORD';  ApplyValue=0; Description='Disable typosquatting (website spelling mistake) checker.'},
        @{Name='PromotionalTabsEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable promotional tabs.'},
        @{Name='EnhanceSecurityMode';                  Type='DWORD';  ApplyValue=0; Description='Disable Enhance Security Mode.'},
        @{Name='SpeechRecognitionEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Speech Recognition.'}
    )
    'Autofill & Passwords' = @(
        @{Name='PasswordGeneratorEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Password Generator.'},
        @{Name='PasswordManagerEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable built-in password manager.'},
        @{Name='PasswordMonitorAllowed';               Type='DWORD';  ApplyValue=0; Description='Disable compromised password monitor.'},
        @{Name='PasswordProtectionWarningTrigger';     Type='DWORD';  ApplyValue=0; Description='Disable password protection warnings.'},
        @{Name='AutofillAddressEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable address autofill.'},
        @{Name='AutofillCreditCardEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable credit card autofill.'},
        @{Name='AutofillMembershipsEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable memberships autofill.'},
        @{Name='PaymentMethodQueryEnabled';            Type='DWORD';  ApplyValue=0; Description='Block sites from checking saved payments.'},
        @{Name='PasswordDismissCompromisedAlertEnabled';Type='DWORD';  ApplyValue=0; Description='Disable dismissing password warnings.'},
        @{Name='EdgeAutofillMlEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Machine Learning for autofill forms.'}
    )
    'Search & Suggestions' = @(
        @{Name='NewTabPageSearchBox';                  Type='STRING'; ApplyValue='redirect'; Description='Redirect NTP search to Address bar.'},
        @{Name='AlternateErrorPagesEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable alternate HTTP error suggest pages.'},
        @{Name='ResolveNavigationErrorsUseWebService'; Type='DWORD';  ApplyValue=0; Description='Disable web service connection probing.'},
        @{Name='SearchForImageEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable context menu Image Search.'},
        @{Name='SearchFiltersEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable suggestions search filters.'},
        @{Name='SearchbarAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable search bar desktop widget.'},
        @{Name='SearchbarIsEnabledOnStartup';          Type='DWORD';  ApplyValue=0; Description='Disable search widget on startup.'},
        @{Name='WebWidgetAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable Web Widget entirely.'},
        @{Name='AddressBarWorkSearchResultsEnabled';   Type='DWORD';  ApplyValue=0; Description='Disable work suggestions in address bar.'},
        @{Name='AddressBarTrendingSuggestEnabled';     Type='DWORD';  ApplyValue=0; Description='Disable Bing trending suggestions.'}
    )
    'AI & Copilot' = @(
        @{Name='ComposeInlineEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable writing assistant Rewrite/Compose.'},
        @{Name='AllowBrowsingWithCopilot';             Type='DWORD';  ApplyValue=0; Description='Disable invoking Copilot for page queries.'},
        @{Name='BuiltInAIAPIsEnabled';                 Type='DWORD';  ApplyValue=0; Description='Disable built-in client AI APIs for web pages.'},
        @{Name='Microsoft365CopilotChatIconEnabled';   Type='DWORD';  ApplyValue=0; Description='Hide the M365 Copilot Chat icon.'},
        @{Name='CopilotPageContextEnabled';            Type='DWORD';  ApplyValue=0; Description='Block Copilot side pane accessing page content.'},
        @{Name='EdgeEntraCopilotPageContext';          Type='DWORD';  ApplyValue=0; Description='Block Entra Copilot accessing page context.'},
        @{Name='EdgeHistoryAISearchEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable AI search in history.'},
        @{Name='AIGenThemesEnabled';                   Type='DWORD';  ApplyValue=0; Description='Disable generating themes using DALL-E.'},
        @{Name='GenAILocalFoundationalModelSettings';  Type='DWORD';  ApplyValue=1; Description='Do not download local foundational GenAI model.'},
        @{Name='CopilotMode';                          Type='DWORD';  ApplyValue=0; Description='Disable Copilot mode entirely.'},
        @{Name='CopilotMultitabEnabled';               Type='DWORD';  ApplyValue=0; Description='Disable Copilot multitab context features.'},
        @{Name='CopilotNewTabPageEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Copilot features on NTP.'},
        @{Name='CopilotPageContext';                   Type='DWORD';  ApplyValue=0; Description='Broadly block Copilot page context.'},
        @{Name='EdgeEntraCopilotPageContextIncludesHistory';Type='DWORD'; ApplyValue=0; Description='Exclude history from Entra Copilot context.'},
        @{Name='M365LinksAutoOpenCopilotEnabled';      Type='DWORD';  ApplyValue=0; Description='Do not auto-open Copilot for M365 links.'},
        @{Name='ShareBrowsingHistoryWithCopilotSearchAllowed';Type='DWORD'; ApplyValue=0; Description='Do not share browsing history with Copilot.'},
        @{Name='CopilotAddressBarSuggestionsEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable Copilot address bar suggestions.'}
    )
    'Performance & System' = @(
        @{Name='BackgroundModeEnabled';                Type='DWORD';  ApplyValue=0; Description='Do not run background apps when Edge closes.'},
        @{Name='StartupBoostEnabled';                  Type='DWORD';  ApplyValue=0; Description='Disable Startup Boost.'},
        @{Name='NetworkPredictionOptions';             Type='DWORD';  ApplyValue=2; Description='Never predict network actions/prefetch.'},
        @{Name='HardwareAccelerationModeEnabled';      Type='DWORD';  ApplyValue=1; Description='Force hardware acceleration mode (GPU).'},
        @{Name='SleepingTabsEnabled';                  Type='DWORD';  ApplyValue=1; Description='Enable putting idle tabs to sleep.'},
        @{Name='EfficiencyModeEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Efficiency Mode.'},
        @{Name='HighEfficiencyModeEnabled';            Type='DWORD';  ApplyValue=0; Description='Disable High Efficiency Mode.'},
        @{Name='ExtensionsPerformanceDetectorEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable extension performance detector.'},
        @{Name='PerformanceDetectorEnabled';           Type='DWORD';  ApplyValue=0; Description='Disable tab performance detector.'},
        @{Name='NewTabPageContentEnabled';             Type='DWORD';  ApplyValue=0; Description='Disable Enterprise NTP content.'},
        @{Name='NewTabPageAppLauncherEnabled';         Type='DWORD';  ApplyValue=0; Description='Hide App Launcher on NTP.'},
        @{Name='NewTabPageBingChatEnabled';            Type='DWORD';  ApplyValue=0; Description='Hide Bing Chat on NTP.'},
        @{Name='NewTabPageQuickLinksEnabled';          Type='DWORD';  ApplyValue=0; Description='Hide Quick Links on NTP.'},
        @{Name='SpotlightExperiencesAndRecommendationsEnabled';Type='DWORD'; ApplyValue=0; Description='Disable Spotlight and custom wallpapers.'},
        @{Name='ExtensionManifestV2Availability';      Type='DWORD';  ApplyValue=2; Description='Allow Manifest V2 extensions.'},
        @{Name='BuiltInDnsClientEnabled';              Type='DWORD';  ApplyValue=0; Description='Disable the built-in DNS client.'},
        @{Name='ProactiveAuthWorkflowEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable proactive auth with MSN/Bing/Copilot.'},
        @{Name='ApplicationGuardFavoritesSyncEnabled';  Type='DWORD';  ApplyValue=0; Description='Disable sync of favorites to App Guard.'},
        @{Name='ApplicationGuardTrafficIdentificationEnabled';Type='DWORD'; ApplyValue=0; Description='Disable outbound App Guard traffic headers.'},
        @{Name='SeamlessWebToBrowserSignInEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable seamless web-to-browser sign-in.'},
        @{Name='AADWebSiteSSOUsingThisProfileEnabled'; Type='DWORD';  ApplyValue=0; Description='Disable AAD Web site SSO.'},
        @{Name='AADWebSSOAllowed';                     Type='DWORD';  ApplyValue=0; Description='Disable AAD Web SSO.'},
        @{Name='MSAWebSiteSSOUsingThisProfileAllowed'; Type='DWORD';  ApplyValue=0; Description='Disable MSA Web site SSO.'},
        @{Name='ImplicitSignInEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Implicit Sign-In.'},
        @{Name='ConfigureOnlineTextToSpeech';          Type='DWORD';  ApplyValue=0; Description='Disable Online Text-to-Speech voices.'},
        @{Name='ConfigureOnPremisesAccountAutoSignIn'; Type='DWORD';  ApplyValue=0; Description='Disable Azure AD auto sign-in.'},
        @{Name='MAMEnabled';                           Type='DWORD';  ApplyValue=0; Description='Disable Intune MAM policy retrieval.'},
        @{Name='EdgeManagementEnabled';                Type='DWORD';  ApplyValue=0; Description='Disable Edge management service.'},
        @{Name='ApplicationBoundEncryptionEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable app-bound local data encryption.'},
        @{Name='ImportBrowserSettings';                Type='DWORD';  ApplyValue=0; Description='Disable importing settings from other browsers.'},
        @{Name='WhatsNewPageForEntraProfilesEnabled';   Type='DWORD';  ApplyValue=0; Description='Disable "What`s New" page for Entra profiles.'},
        @{Name='QuickSearchShowMiniMenu';              Type='DWORD';  ApplyValue=0; Description='Disable quick search mini menu.'},
        @{Name='MicrosoftEditorSynonymsEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Editor synonyms.'},
        @{Name='MicrosoftEditorProofingEnabled';       Type='DWORD';  ApplyValue=0; Description='Disable Microsoft Editor proofing.'},
        @{Name='SpellcheckEnabled';                    Type='DWORD';  ApplyValue=0; Description='Disable spellcheck.'},
        @{Name='ScarewareBlockerProtectionEnabled';    Type='DWORD';  ApplyValue=0; Description='Disable Scareware blocker.'},
        @{Name='BingAdsSuppression';                   Type='DWORD';  ApplyValue=1; Description='Suppress ads on Bing.com search.'},
        @{Name='DefaultBrowserSettingEnabled';         Type='DWORD';  ApplyValue=0; Description='Disable default browser check on startup.'}
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
    }
    'Install Minimal New Tab extension' = @{
        SubKey = "ExtensionInstallForcelist"
        Name   = "1"
        Value  = "khdnagehanbomfdogegmpddmcalmdnbg"
        Type   = "String"
        Description = "Force installs Minimal New Tab plugin (khdnagehanbomfdogegmpddmcalmdnbg)."
    }
    'Allow Google Cookies' = @{
        SubKey = "CookiesAllowedForUrls"
        Name   = "1"
        Value  = "[*.]google.com"
        Type   = "String"
        Description = "Allows storing Google cookies to prevent getting signed out."
    }
    'Google Web Only (ManagedSearchEngines)' = @{
        Name   = "ManagedSearchEngines"
        Value  = "[{`"is_default`":true,`"keyword`":`"google.com`",`"name`":`"Google`",`"search_url`":`"https://www.google.com/search?q={searchTerms}&udm=14`",`"suggest_url`":`"https://www.google.com/complete/search?output=chrome&q={searchTerms}`"}]"
        Type   = "String"
        Description = "Sets Google Web (no AI) as default Managed Search Engine."
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
$subBannerLabel.Size = New-Object System.Drawing.Size(600, 20)
$banner.Controls.Add($subBannerLabel)

# Tab Control for Categories
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 70)
$tabControl.Size = New-Object System.Drawing.Size(815, 420)
$tabControl.Font = $fontNormal
$form.Controls.Add($tabControl)

$script:CheckBoxes = @()

# Load checkboxes dynamically based on categories
foreach ($category in $script:Policies.Keys) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $category
    $tabPage.BackColor = $panelBgColor
    
    # Scrollable panel within tab
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.AutoScroll = $true
    $tabPage.Controls.Add($panel)
    
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
    
    $tabControl.TabPages.Add($tabPage)
}

# Special tab for overrides/extra policies
$tabPageSpecials = New-Object System.Windows.Forms.TabPage
$tabPageSpecials.Text = "Advanced Overrides"
$tabPageSpecials.BackColor = $panelBgColor

$panelSpecials = New-Object System.Windows.Forms.Panel
$panelSpecials.Dock = [System.Windows.Forms.DockStyle]::Fill
$panelSpecials.AutoScroll = $true
$tabPageSpecials.Controls.Add($panelSpecials)

$script:SpecialCheckBoxes = @()
$yPos = 15
foreach ($key in $script:Specials.Keys) {
    $spec = $script:Specials[$key]
    $chk = New-Object System.Windows.Forms.CheckBox
    $policyName = if ($spec.SubKey) { $spec.SubKey } else { $spec.Name }
    $chk.Text = "$policyName - $($spec.Description)"
    $chk.Size = New-Object System.Drawing.Size(760, 24)
    $chk.Location = New-Object System.Drawing.Point(15, $yPos)
    $chk.Tag = $key # store key name
    $panelSpecials.Controls.Add($chk)
    $script:SpecialCheckBoxes += $chk
    $yPos += 28
}

# GroupBox for Custom Configurations
$groupCustom = New-Object System.Windows.Forms.GroupBox
$groupCustom.Text = "Policy Customizations (Tracking Prevention, Sleeping Tabs & DoH)"
$groupCustom.Size = New-Object System.Drawing.Size(765, 200)
$groupCustom.Location = New-Object System.Drawing.Point(15, ($yPos + 10))
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

$tabControl.TabPages.Add($tabPageSpecials)

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
        $stCur = Get-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -ErrorAction SilentlyContinue
        if ($null -ne $stCur) {
            $script:ChkSleepingEnabled.Checked = $true
            $stVal = $stCur.SleepingTabsTimeout
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
            New-ItemProperty -Path $script:EdgePolicyPath -Name "SleepingTabsTimeout" -Value $stVal -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Log "SET SleepingTabsTimeout = $stVal" "OK"
            $applied++
        } catch {
            Write-Log "FAILED to set SleepingTabsTimeout: $_" "ERR"
        }
    } else {
        try {
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
$bottomPanel.Controls.Add($btnLoad)

# Select All Button
$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Select All"
$btnSelectAll.Size = New-Object System.Drawing.Size(100, 32)
$btnSelectAll.Location = New-Object System.Drawing.Point(130, 5)
$btnSelectAll.Font = $fontNormal
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
$bottomPanel.Controls.Add($btnRestore)

# Close Button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Size = New-Object System.Drawing.Size(100, 32)
$btnClose.Location = New-Object System.Drawing.Point(715, 5)
$btnClose.Font = $fontNormal
$btnClose.Add_Click({ $form.Close() })
$bottomPanel.Controls.Add($btnClose)

# Startup Initialization
$form.Add_Shown({
    Load-RegistryState
})

# Show UI Form
[void]$form.ShowDialog()
