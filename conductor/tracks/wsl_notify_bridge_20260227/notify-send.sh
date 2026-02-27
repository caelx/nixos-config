#!/usr/bin/env bash

# notify-send (WSL to Windows Bridge)
# A drop-in replacement for notify-send that forwards notifications to Windows.

APP_NAME="WSL"
URGENCY="normal"
EXPIRE_TIME=""
ICON=""
SUMMARY=""
BODY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--app-name)
            APP_NAME="$2"
            shift 2
            ;;
        -u|--urgency)
            URGENCY="$2"
            shift 2
            ;;
        -t|--expire-time)
            EXPIRE_TIME="$2"
            shift 2
            ;;
        -i|--icon)
            ICON="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: notify-send [OPTIONS] <SUMMARY> [BODY]"
            echo "Options:"
            echo "  -a, --app-name=APP_NAME   Specify the application name."
            echo "  -i, --icon=ICON           Specify an icon."
            echo "  -u, --urgency=LEVEL       Specify the urgency level (low, normal, critical)."
            echo "  -t, --expire-time=TIME    Specify the timeout in milliseconds."
            exit 0
            ;;
        -*)
            # Ignore unknown options for now to maintain compatibility
            shift
            ;;
        *)
            if [ -z "$SUMMARY" ]; then
                SUMMARY="$1"
            elif [ -z "$BODY" ]; then
                BODY="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$SUMMARY" ]; then
    echo "Error: At least a summary must be provided."
    exit 1
fi

# Escape single quotes for PowerShell
SUMMARY_ESCAPED=$(echo "$SUMMARY" | sed "s/'/''/g")
BODY_ESCAPED=$(echo "$BODY" | sed "s/'/''/g")
APP_NAME_ESCAPED=$(echo "$APP_NAME" | sed "s/'/''/g")

# PowerShell command
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
    
    # Locate Windows Terminal Icon for branding if no icon is specified
    # Or always use it if requested
    \$iconPath = \$null
    \$wtPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal
    if (\$wtPackage) {
        \$iconPath = Join-Path \$wtPackage.InstallLocation 'Images\Square44x44Logo.targetsize-256.png'
    }

    # Template
    \$Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)
    \$RawXml = [xml]\$Template.GetXml()
    
    # Set Text
    (\$RawXml.toast.visual.binding.text | Where-Object { \$_.id -eq '1' }).AppendChild(\$RawXml.CreateTextNode('$SUMMARY_ESCAPED')) > \$null
    (\$RawXml.toast.visual.binding.text | Where-Object { \$_.id -eq '2' }).AppendChild(\$RawXml.CreateTextNode('$BODY_ESCAPED')) > \$null
    
    # Set Image
    if (\$iconPath -and (Test-Path \$iconPath)) {
        \$imageNode = (\$RawXml.toast.visual.binding.image | Where-Object { \$_.id -eq '1' })
        if (\$imageNode) { \$imageNode.SetAttribute('src', \$iconPath) }
    }
    
    \$SerializedXml = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
    \$SerializedXml.LoadXml(\$RawXml.OuterXml)
    
    \$Toast = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]::New(\$SerializedXml)
    \$Toast.Tag = '$APP_NAME_ESCAPED'
    \$Toast.Group = 'WSL'
    
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('PowerShell').Show(\$Toast)
"
